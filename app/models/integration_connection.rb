# Le compte d'une personne dans un outil du client. Les jetons OAuth restent chiffrés et ne quittent jamais
# SG Mail : ni l'API, ni Claude ne les voient. Sert aussi de stockage au client OAuth du gem mcp
# (tokens, client_information, autorisations en cours), voir RemoteMcp.
class IntegrationConnection < ApplicationRecord
  PENDING_MAX_AGE = 10.minutes

  acts_as_tenant :account
  belongs_to :integration
  belongs_to :user

  serialize :oauth, coder: JSON
  encrypts :oauth

  scope :connected, -> { where.not(connected_at: nil) }

  def connected? = connected_at.present?

  def disconnect!
    update!(connected_at: nil, oauth: oauth_data.slice("redirect_uri", "client_information"))
  end

  def redirect_uri = oauth_data["redirect_uri"]

  def tools_list = tools.map { |tool| tool.is_a?(Hash) ? tool : {} }

  # Stockage attendu par MCP::Client::OAuth::Provider.
  def tokens = oauth_data["tokens"]
  def save_tokens(tokens) = write_oauth("tokens" => tokens)
  def client_information = oauth_data["client_information"]
  def save_client_information(info) = write_oauth("client_information" => info)

  def save_pending_authorization(state, pending)
    fresh = oauth_data.fetch("pending", {}).reject { |_state, entry| expired?(entry) }
    write_oauth("pending" => fresh.merge(state => pending))
  end

  def pending_authorization(state) = oauth_data.dig("pending", state)

  # Retire et rend l'autorisation en une fois : deux retours concurrents avec le même state, un seul passe.
  def delete_pending_authorization(state)
    with_lock do
      pending = oauth_data.fetch("pending", {})
      entry = pending.delete(state)
      write_oauth("pending" => pending) if entry
      entry
    end
  end

  def inspect = "#<IntegrationConnection id=#{id} integration_id=#{integration_id} user_id=#{user_id} connected=#{connected?}>"

  private

  def oauth_data = oauth.is_a?(Hash) ? oauth : {}

  def write_oauth(values)
    self.oauth = oauth_data.merge(values)
    save!
  end

  def expired?(entry)
    created_at = entry.is_a?(Hash) ? entry["created_at"] : nil
    created_at.is_a?(Integer) && Time.now.to_i - created_at > PENDING_MAX_AGE.to_i
  end
end
