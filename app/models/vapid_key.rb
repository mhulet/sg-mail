# La paire de clés VAPID qui signe nos envois Web Push. Par défaut, elle est dérivée de secret_key_base :
# rien à configurer, et elle reste la même d'un déploiement à l'autre. VAPID_PUBLIC_KEY et VAPID_PRIVATE_KEY
# (base64url) la remplacent si besoin. Changer de clé oblige chaque appareil à réactiver les notifications.
module VapidKey
  SUBJECT = "mailto:team@supergenial.be"

  module_function

  def details
    { subject: SUBJECT, public_key: public_key, private_key: private_key }
  end

  def public_key
    ENV["VAPID_PUBLIC_KEY"].presence || derived.fetch(:public_key)
  end

  def private_key
    ENV["VAPID_PRIVATE_KEY"].presence || derived.fetch(:private_key)
  end

  def derived
    @derived ||= begin
      group = OpenSSL::PKey::EC::Group.new("prime256v1")
      secret = Rails.application.key_generator.generate_key("sg_mail web push vapid", 32)
      scalar = OpenSSL::BN.new(secret, 2) % (group.order - 1) + 1
      point = group.generator.mul(scalar)
      { private_key: encode(scalar.to_s(2).rjust(32, "\0")), public_key: encode(point.to_octet_string(:uncompressed)) }
    end
  end

  def encode(bytes) = Base64.urlsafe_encode64(bytes, padding: false)
end
