# Serveur MCP distant (HTTP « streamable », sans état, réponses JSON seulement).
# Chaque requête porte un jeton personnel ou un jeton OAuth ; elle s'exécute dans le client de ce jeton.
class McpController < ActionController::API
  around_action :authenticate

  def create
    response_json = SgMailMcp.server(user: Current.user, base_url: request.base_url).handle_json(request.raw_post)
    response_json ? render(json: response_json) : head(:accepted)
  end

  # Pas de flux ouvert par le serveur ni de session à fermer en mode sans état.
  def unsupported
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end

  private

  def authenticate(&block)
    Current.membership = BearerAuth.membership_for(request)
    unless Current.membership
      response.set_header("WWW-Authenticate", %(Bearer resource_metadata="#{oauth_protected_resource_url}"))
      return render(json: { error: "invalid_token" }, status: :unauthorized)
    end

    Tenancy.with_account(Current.account, &block)
  end
end
