# Jeton personnel (API, CLI, MCP depuis Claude Code) : il agit au nom d'une personne, dans un client.
# Le jeton n'est montré qu'une fois, à sa création ; on ne garde que son empreinte.
class ApiToken < ApplicationRecord
  belongs_to :user
  belongs_to :account

  attr_reader :token

  validates :name, presence: true, length: { maximum: 100 }

  before_validation on: :create do
    @token = "sgm_#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@token)
  end

  def self.digest(secret) = OpenSSL::Digest::SHA256.hexdigest(secret.to_s)

  def self.authenticate(secret)
    find_by(token_digest: digest(secret)) if secret.present?
  end

  def touch_last_used
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 5.minutes.ago
  end
end
