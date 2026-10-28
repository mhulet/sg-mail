# Un appareil qui reçoit les notifications de SG Mail (Web Push). Le navigateur donne l'adresse de son
# service de push (endpoint) et les clés qui chiffrent le contenu : Apple, Google ou Mozilla ne lisent rien.
class PushSubscription < ApplicationRecord
  belongs_to :user

  # Qui envoie vraiment (remplacé dans les tests).
  cattr_accessor :transport, default: ->(**options) { WebPush.payload_send(**options) }

  validates :endpoint, :p256dh, :auth, :name, presence: true
  validates :endpoint, uniqueness: true

  # Envoie une notification ; un abonnement que le service de push ne connaît plus (app désinstallée,
  # notifications coupées) est supprimé.
  def deliver(title:, body:, url: "/", tag: nil, badge: nil)
    payload = { title: title, body: body, url: url, tag: tag, badge: badge }.compact.to_json
    transport.call(message: payload, endpoint: endpoint, p256dh: p256dh, auth: auth, vapid: VapidKey.details, ttl: 24.hours.to_i, urgency: "high")
    touch(:last_used_at)
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized
    destroy
    false
  end
end
