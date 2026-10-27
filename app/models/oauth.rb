# Serveur d'autorisation OAuth 2.1 utilisé par le MCP (connecteurs claude.ai).
# Les secrets (codes, jetons) ne sont jamais stockés : seulement leur empreinte SHA-256.
module Oauth
  def self.table_name_prefix = "oauth_"

  def self.generate_secret(prefix) = "#{prefix}_#{SecureRandom.urlsafe_base64(32)}"

  def self.digest(secret) = OpenSSL::Digest::SHA256.hexdigest(secret.to_s)
end
