# Connecter son propre compte à un outil du client : OAuth 2.1 vers le serveur de l'outil, retour sur une
# adresse fixe (/integrations/callback). Le compte distant peut différer de l'adresse SG Mail.
class IntegrationConnectionsController < ApplicationController
  include AccountScoped

  rescue_from RemoteMcp::AuthorizationRequired do |error|
    if error.authorization_url
      redirect_to error.authorization_url.to_s, allow_other_host: true
    else
      redirect_to integrations_path, alert: "#{@integration&.name || "L'outil"} n'a pas accepté la connexion. Réessaie dans un instant."
    end
  end

  def create
    @integration = Integration.find(params[:integration_id])
    connection = @integration.connections.find_or_create_by!(user: Current.user)
    session[:integration_connection] = { "id" => connection.id, "account_id" => current_account.id }
    RemoteMcp.new(connection).authorize!("#{request.base_url}#{RemoteMcp::CALLBACK_PATH}")
    redirect_to integrations_path, notice: connected_notice(connection)
  rescue RemoteMcp::AuthorizationRequired
    raise
  rescue StandardError => error
    Rails.logger.warn("Outil #{@integration&.id} : #{error.class} #{error.message}")
    redirect_to integrations_path, alert: "Impossible de joindre #{@integration&.name} (#{error.class.name.demodulize}). Vérifie son adresse MCP."
  end

  def callback
    pending = session.delete(:integration_connection) || {}
    connection = IntegrationConnection.find_by(id: pending["id"], user: Current.user)
    return redirect_to integrations_path, alert: "Connexion expirée : recommence depuis Réglages → Outils." unless connection
    return redirect_to integrations_path, alert: "Connexion à #{connection.integration.name} annulée." if params[:error].present?

    @integration = connection.integration
    RemoteMcp.new(connection).finish!(request.query_parameters)
    redirect_to integrations_path, notice: connected_notice(connection)
  rescue RemoteMcp::AuthorizationRequired
    raise
  rescue StandardError => error
    Rails.logger.warn("Outil #{@integration&.id} : #{error.class} #{error.message}")
    redirect_to integrations_path, alert: "Connexion à #{@integration&.name} refusée ou expirée. Recommence."
  end

  def destroy
    connection = IntegrationConnection.find_by!(integration_id: params[:integration_id], user: Current.user)
    connection.destroy!
    redirect_to integrations_path, notice: "#{connection.integration.name} déconnecté : l'agent ne l'utilise plus pour toi."
  end

  private

  # L'outil rappelle une adresse fixe : le client vient de la session.
  def requested_account_id = params[:account_id] || session.dig(:integration_connection, "account_id")

  def connected_notice(connection)
    who = connection.reload.remote_identity
    "#{connection.integration.name} connecté#{" en tant que #{who}" if who}. #{connection.tools_list.size} outils disponibles pour l'agent."
  end
end
