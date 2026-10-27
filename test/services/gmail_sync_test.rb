require "test_helper"

class GmailSyncTest < ActiveSupport::TestCase
  G = Google::Apis::GmailV1

  # Imite le strict nécessaire de Google::Apis::GmailV1::GmailService.
  class FakeGmail
    attr_accessor :messages, :history_id, :histories, :history_error, :quota_errors

    def initialize
      @messages = {}
      @history_id = 100
      @histories = []
      @quota_errors = 0
    end

    def get_user_profile(_user) = G::Profile.new(email_address: "formations@semisto.org", history_id: history_id)

    def list_user_messages(_user, max_results:, page_token: nil, **)
      ids = messages.keys
      offset = page_token.to_i
      page = ids[offset, 2]
      next_token = (offset + 2 < ids.size) ? (offset + 2).to_s : nil
      G::ListMessagesResponse.new(messages: page.map { |id| G::Message.new(id: id) }, next_page_token: next_token)
    end

    def batch = yield(self)

    def get_user_message(_user, id, format:)
      if quota_errors.positive?
        self.quota_errors -= 1
        yield nil, Google::Apis::ClientError.new("PERMISSION_DENIED: Quota exceeded for quota metric 'Total Query Cost'", status_code: 403)
      elsif (message = messages[id])
        yield message, nil
      else
        yield nil, Google::Apis::ClientError.new("Not Found", status_code: 404)
      end
    end

    def list_user_histories(_user, start_history_id:, **)
      if (error = history_error)
        self.history_error = nil # erreur ponctuelle
        raise error
      end

      G::ListHistoryResponse.new(history: histories.select { |h| h.id > start_history_id.to_i }, history_id: history_id)
    end

    def add(id, subject, labels: %w[INBOX UNREAD])
      raw = "From: a@example.org\r\nSubject: #{subject}\r\nMessage-ID: <#{id}@example.org>\r\n\r\nBonjour\r\n"
      messages[id] = G::Message.new(id: id, thread_id: "t-#{id}", label_ids: labels, raw: raw, snippet: "Bonjour")
    end
  end

  setup do
    ENV["GOOGLE_CLIENT_ID"] ||= "test"
    ENV["GOOGLE_CLIENT_SECRET"] ||= "test"
    @mailbox = Mailbox.create!(provider: "gmail", address: "formations@semisto.org",
      credentials: { "refresh_token" => "r", "access_token" => "a", "expires_at" => 1.hour.from_now.to_i })
    @gmail = FakeGmail.new
    %w[m1 m2 m3].each_with_index { |id, i| @gmail.add(id, "Message #{i + 1}") }
  end

  def sync(**options)
    GmailSync.new(@mailbox.reload, **options).tap do |sync|
      sync.instance_variable_set(:@service, @gmail)
      sync.define_singleton_method(:sleep) { |_seconds| } # pas d'attente réelle en test
    end.call
  end

  test "import complet paginé puis historique incrémental" do
    sync
    assert_equal 3, @mailbox.messages.count
    assert_equal "100", @mailbox.reload.sync_state["history_id"].to_s
    assert_equal %w[INBOX UNREAD], @mailbox.messages.find_by(provider_uid: "m1").labels

    @gmail.add("m4", "Nouveau")
    @gmail.history_id = 105
    @gmail.histories = [
      G::History.new(id: 101, messages_added: [ G::HistoryMessageAdded.new(message: G::Message.new(id: "m4")) ]),
      G::History.new(id: 102, messages_deleted: [ G::HistoryMessageDeleted.new(message: G::Message.new(id: "m2")) ]),
      G::History.new(id: 103, labels_removed: [ G::HistoryLabelRemoved.new(message: G::Message.new(id: "m1", label_ids: %w[INBOX])) ])
    ]
    sync

    assert_equal %w[m1 m3 m4], @mailbox.messages.order(:provider_uid).pluck(:provider_uid)
    assert_equal %w[INBOX], @mailbox.messages.find_by(provider_uid: "m1").labels
    assert_equal "105", @mailbox.reload.sync_state["history_id"].to_s
  end

  test "historyId expiré : réimport complet" do
    sync
    @gmail.history_error = Google::Apis::ClientError.new("Not Found", status_code: 404)
    @gmail.add("m5", "Arrivé pendant l'absence")
    @gmail.history_id = 200

    sync
    assert_equal 4, @mailbox.messages.count
    assert_equal "200", @mailbox.reload.sync_state["history_id"].to_s
  end

  test "quota dépassé : attend puis reprend" do
    @gmail.quota_errors = 2
    sync
    assert_equal 3, @mailbox.messages.count
  end

  test "quota toujours dépassé : abandonne avec l'erreur de Google" do
    @gmail.quota_errors = 1_000
    assert_raises(Google::Apis::ClientError) { sync }
  end

  test "limite d'import" do
    sync(import_limit: 2)
    assert_equal 2, @mailbox.messages.count
  end
end
