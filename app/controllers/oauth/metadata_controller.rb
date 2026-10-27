# Documents de découverte qui permettent aux clients MCP de trouver seuls le serveur d'autorisation.
class Oauth::MetadataController < ActionController::API
  # RFC 9728 : métadonnées de la ressource protégée, annoncées par /mcp dans WWW-Authenticate.
  def protected_resource
    render json: {
      resource: mcp_url,
      authorization_servers: [ request.base_url ],
      bearer_methods_supported: [ "header" ],
      resource_name: "SG Mail"
    }
  end

  # RFC 8414 : métadonnées du serveur d'autorisation.
  def authorization_server
    render json: {
      issuer: request.base_url,
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_registration_url,
      revocation_endpoint: oauth_revocation_url,
      response_types_supported: [ "code" ],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: [ "S256" ],
      token_endpoint_auth_methods_supported: [ "none" ],
      revocation_endpoint_auth_methods_supported: [ "none" ]
    }
  end
end
