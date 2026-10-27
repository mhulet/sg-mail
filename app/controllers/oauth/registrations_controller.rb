# Enregistrement dynamique des clients (RFC 7591). S'enregistrer ne donne accès à rien :
# chaque client doit encore être approuvé par une personne connectée, sur l'écran de consentement.
class Oauth::RegistrationsController < ActionController::API
  rate_limit to: 10, within: 1.hour, only: :create,
    with: -> { render json: { error: "slow_down" }, status: :too_many_requests }

  def create
    client = Oauth::Client.new(name: params[:client_name].presence || "Client MCP", redirect_uris: Array(params[:redirect_uris]).map(&:to_s))
    if client.save
      render json: {
        client_id: client.uid,
        client_name: client.name,
        redirect_uris: client.redirect_uris,
        client_id_issued_at: client.created_at.to_i,
        grant_types: %w[authorization_code refresh_token],
        response_types: [ "code" ],
        token_endpoint_auth_method: "none"
      }, status: :created
    else
      render json: { error: "invalid_client_metadata", error_description: client.errors.full_messages.to_sentence }, status: :bad_request
    end
  end
end
