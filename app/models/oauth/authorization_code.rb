# Code à usage unique et de courte durée, échangé contre des jetons sur /oauth/token, lié à un défi PKCE.
class Oauth::AuthorizationCode < ApplicationRecord
  TTL = 10.minutes

  belongs_to :client, class_name: "Oauth::Client", foreign_key: :oauth_client_id, inverse_of: :authorization_codes
  belongs_to :user
  belongs_to :account

  attr_reader :code

  validates :redirect_uri, :code_challenge, presence: true

  before_validation on: :create do
    @code = Oauth.generate_secret("sgmc")
    self.code_digest = Oauth.digest(@code)
    self.expires_at ||= TTL.from_now
  end

  def self.find_by_code(code)
    find_by(code_digest: Oauth.digest(code)) if code.present?
  end

  def usable? = used_at.nil? && expires_at.future?

  # PKCE en S256 uniquement (OAuth 2.1).
  def verifier_matches?(verifier)
    return false if verifier.blank?

    computed = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(computed, code_challenge)
  end

  # Marque le code comme utilisé et émet les jetons, ou rend nil s'il a déjà servi (rejeu).
  def redeem!
    with_lock do
      return unless usable?

      update!(used_at: Time.current)
      Oauth::Token.issue!(client: client, user: user, account: account)
    end
  end
end
