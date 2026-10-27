# Notifications temps réel Gmail : users.watch publie chaque changement de la boîte sur le sujet
# Pub/Sub de SG Mail (GMAIL_PUBSUB_TOPIC), qui appelle /webhooks/gmail. La surveillance expire
# après 7 jours : on la renouvelle à chaque synchro quand il reste moins d'un jour.
class GmailWatch
  RENEW_BEFORE = 1.day

  def self.topic = ENV["GMAIL_PUBSUB_TOPIC"].presence

  def initialize(mailbox, service: nil)
    @mailbox = mailbox
    @service = service
  end

  def renew_if_needed
    return unless self.class.topic && due?

    response = service.watch_user("me", Google::Apis::GmailV1::WatchRequest.new(topic_name: self.class.topic))
    @mailbox.update!(sync_state: @mailbox.sync_state.merge("watch_expires_at" => response.expiration.to_i / 1000))
  rescue Google::Apis::Error => e
    # La synchro périodique prend le relais : un souci de Pub/Sub ne doit pas la faire échouer.
    Rails.logger.warn("Gmail watch #{@mailbox.address} : #{e.class}: #{e.message}")
  end

  private

  def due?
    expires_at = @mailbox.sync_state["watch_expires_at"]
    expires_at.nil? || Time.at(expires_at) < RENEW_BEFORE.from_now
  end

  def service
    @service ||= GoogleOauth.gmail_service(GoogleOauth.for_mailbox(@mailbox))
  end
end
