# Jeton d'accès (une heure) et son jeton de rafraîchissement (renouvelé à chaque usage),
# pour une personne dans un client.
class Oauth::Token < ApplicationRecord
  ACCESS_TTL = 1.hour
  REFRESH_TTL = 30.days

  belongs_to :client, class_name: "Oauth::Client", foreign_key: :oauth_client_id, inverse_of: :tokens
  belongs_to :user
  belongs_to :account

  attr_reader :access_token, :refresh_token

  scope :active, -> { where(revoked_at: nil).where(refresh_expires_at: Time.current..) }

  def self.issue!(client:, user:, account:)
    token = new(client: client, user: user, account: account)
    token.send(:generate_secrets)
    token.save!
    token
  end

  def self.authenticate(access_token)
    return if access_token.blank?

    token = find_by(access_token_digest: Oauth.digest(access_token))
    token if token&.access_usable?
  end

  def self.find_by_refresh_token(refresh_token)
    find_by(refresh_token_digest: Oauth.digest(refresh_token)) if refresh_token.present?
  end

  def access_usable? = revoked_at.nil? && access_expires_at.future?
  def refresh_usable? = revoked_at.nil? && refresh_expires_at.future?

  def revoke! = update!(revoked_at: Time.current)

  # Rotation : l'ancienne paire est révoquée, une nouvelle est émise.
  def rotate!
    with_lock do
      return unless refresh_usable?

      revoke!
      self.class.issue!(client: client, user: user, account: account)
    end
  end

  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 5.minutes.ago
  end

  def as_token_response
    { access_token: access_token, token_type: "Bearer", expires_in: ACCESS_TTL.to_i, refresh_token: refresh_token }
  end

  private

  def generate_secrets
    @access_token = Oauth.generate_secret("sgma")
    @refresh_token = Oauth.generate_secret("sgmr")
    self.access_token_digest = Oauth.digest(@access_token)
    self.refresh_token_digest = Oauth.digest(@refresh_token)
    self.access_expires_at = ACCESS_TTL.from_now
    self.refresh_expires_at = REFRESH_TTL.from_now
  end
end
