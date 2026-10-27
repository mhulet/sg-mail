# Application inscrite par enregistrement dynamique (RFC 7591), par exemple claude.ai.
# Client public : pas de secret, PKCE obligatoire.
class Oauth::Client < ApplicationRecord
  has_many :authorization_codes, foreign_key: :oauth_client_id, dependent: :delete_all, inverse_of: :client
  has_many :tokens, foreign_key: :oauth_client_id, dependent: :delete_all, inverse_of: :client

  validates :uid, presence: true, uniqueness: true
  validates :name, presence: true, length: { maximum: 100 }
  validate :redirect_uris_are_safe

  before_validation { self.uid ||= SecureRandom.uuid }

  def redirect_uri?(uri) = redirect_uris.include?(uri)

  private

  # https seulement, sauf adresses locales pour les clients sur la machine (RFC 8252).
  def redirect_uris_are_safe
    uris = Array(redirect_uris)
    return errors.add(:redirect_uris, "doit contenir entre 1 et 10 adresses") unless uris.size.between?(1, 10)

    uris.each do |value|
      uri = URI.parse(value.to_s)
      loopback = uri.scheme == "http" && %w[localhost 127.0.0.1 [::1]].include?(uri.host)
      errors.add(:redirect_uris, "contient une adresse non sûre : #{value}") unless (uri.scheme == "https" || loopback) && uri.host.present? && uri.fragment.nil?
    rescue URI::InvalidURIError
      errors.add(:redirect_uris, "contient une adresse invalide : #{value}")
    end
  end
end
