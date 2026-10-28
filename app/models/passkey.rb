# Une passkey (WebAuthn) d'une personne : Touch ID, Face ID, Windows Hello, clé de sécurité…
# On garde l'identifiant et la clé publique ; le secret ne quitte jamais l'appareil.
class Passkey < ApplicationRecord
  belongs_to :user

  validates :external_id, :public_key, :name, presence: true
  validates :external_id, uniqueness: true

  # Les réglages WebAuthn pour l'adresse de la requête (SG Mail tourne sous plusieurs hôtes : local, production).
  def self.relying_party(request)
    WebAuthn::RelyingParty.new(id: request.host, name: "SG Mail", allowed_origins: [ request.base_url ])
  end

  def self.default_name(user_agent)
    device = case user_agent.to_s
    when /iPhone/ then "iPhone"
    when /iPad/ then "iPad"
    when /Android/ then "Android"
    when /Macintosh/ then "Mac"
    when /Windows/ then "Windows"
    when /Linux/ then "Linux"
    else "Appareil"
    end
    "#{device}, #{I18n.l(Date.current)}"
  end
end
