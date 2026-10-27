# Import puis synchro incrémentale d'une boîte Gmail via l'API Gmail.
#
# Import initial paginé et reprenable (sync_state["full_page_token"]),
# puis history.list à partir du dernier historyId connu.
class GmailSync
  BATCH_SIZE = 25 # messages.get coûte 5 unités, le quota est de 250 unités/s par utilisateur

  def initialize(mailbox, import_limit: ENV["GMAIL_IMPORT_LIMIT"].presence&.to_i)
    @mailbox = mailbox
    @import_limit = import_limit
    @authorization = GoogleOauth.for_mailbox(mailbox)
    @service = GoogleOauth.gmail_service(@authorization)
  end

  def call
    refresh_token_if_needed
    if state["history_id"].present?
      incremental
    else
      full_import
    end
  rescue Google::Apis::ClientError => e
    raise unless e.status_code == 404 && state["history_id"].present?

    # historyId trop ancien : Google ne garde l'historique qu'environ une semaine.
    save_state("history_id" => nil, "full_page_token" => nil)
    full_import
  end

  private

  attr_reader :mailbox, :service

  def state = mailbox.sync_state

  def save_state(changes)
    mailbox.update!(sync_state: state.merge(changes))
  end

  def full_import
    # On note l'historyId avant l'import pour ne rien perdre de ce qui arrive pendant.
    save_state("pending_history_id" => service.get_user_profile("me").history_id) if state["pending_history_id"].blank?

    page_token = state["full_page_token"]
    imported = state["full_imported"].to_i
    loop do
      page = service.list_user_messages("me", max_results: 500, page_token: page_token, include_spam_trash: false)
      ids = Array(page.messages).map(&:id)
      ids = ids.first(@import_limit - imported) if @import_limit
      fetch_and_store(ids)
      imported += ids.size
      page_token = page.next_page_token
      save_state("full_page_token" => page_token, "full_imported" => imported)
      break if page_token.nil? || (@import_limit && imported >= @import_limit)
    end

    save_state("history_id" => state["pending_history_id"], "pending_history_id" => nil, "full_page_token" => nil)
    incremental
  end

  def incremental
    page_token = nil
    latest_history_id = state["history_id"]
    loop do
      response = service.list_user_histories(
        "me",
        start_history_id: state["history_id"],
        history_types: %w[messageAdded messageDeleted labelAdded labelRemoved],
        page_token: page_token
      )
      Array(response.history).each { |history| apply(history) }
      latest_history_id = response.history_id
      page_token = response.next_page_token
      break if page_token.nil?
    end
    save_state("history_id" => latest_history_id)
  end

  def apply(history)
    added = Array(history.messages_added).map { |h| h.message.id }
    fetch_and_store(added) if added.any?

    Array(history.messages_deleted).each do |h|
      mailbox.messages.where(provider_uid: h.message.id).delete_all
    end

    (Array(history.labels_added) + Array(history.labels_removed)).each do |h|
      mailbox.messages.where(provider_uid: h.message.id).update_all(labels: Array(h.message.label_ids), updated_at: Time.current)
    end
  end

  def fetch_and_store(ids)
    ids.each_slice(BATCH_SIZE) do |slice|
      pending = slice
      attempt = 0
      while pending.any?
        results = fetch_batch(pending)
        throttled = results.select { |_id, result| rate_limited?(result) }.keys

        results.except(*throttled).each do |_id, result|
          next if result.is_a?(Google::Apis::ClientError) && result.status_code == 404 # supprimé entre-temps
          raise result if result.is_a?(StandardError)

          store(result)
        end

        pending = throttled
        attempt += 1
        raise Google::Apis::RateLimitError, "Quota Gmail dépassé" if attempt > 5 && pending.any?
        sleep(2**attempt) if pending.any?
      end
    end
  end

  def fetch_batch(ids)
    results = {}
    service.batch do |batch|
      ids.each do |id|
        batch.get_user_message("me", id, format: "raw") { |message, error| results[id] = error || message }
      end
    end
    results
  end

  def rate_limited?(result)
    result.is_a?(Google::Apis::RateLimitError) ||
      (result.is_a?(Google::Apis::ClientError) && result.status_code.in?([ 403, 429 ]) && result.message.to_s.match?(/rate ?limit/i))
  end

  def store(gmail_message)
    message = mailbox.messages.find_or_initialize_by(provider_uid: gmail_message.id)
    message.assign_attributes(MessageParser.parse(gmail_message.raw))
    message.thread_key = gmail_message.thread_id
    message.labels = Array(gmail_message.label_ids)
    message.snippet = gmail_message.snippet.presence || message.snippet
    message.save!
  end

  def refresh_token_if_needed
    return unless @authorization.access_token.blank? || @authorization.expires_within?(60)

    @authorization.refresh!
    mailbox.update!(credentials: mailbox.credentials.merge(
      "access_token" => @authorization.access_token,
      "expires_at" => @authorization.expires_at&.to_i
    ))
  end
end
