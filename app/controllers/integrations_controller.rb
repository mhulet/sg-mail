# Réglages → Outils : les outils du client que l'agent peut utiliser. Un admin les déclare ;
# chaque membre y connecte son propre compte (IntegrationConnectionsController).
class IntegrationsController < ApplicationController
  include AccountScoped
  before_action :require_admin, only: %i[create destroy]

  def index
    @integrations = Integration.alphabetical.to_a
    @connections = IntegrationConnection.where(user: Current.user).index_by(&:integration_id)
    @integration = Integration.new
  end

  def create
    @integration = Integration.new(params.expect(integration: %i[name mcp_url]))
    if @integration.save
      redirect_to integrations_path, notice: "#{@integration.name} ajouté. Chaque membre peut maintenant y connecter son compte."
    else
      @integrations = Integration.alphabetical.to_a
      @connections = IntegrationConnection.where(user: Current.user).index_by(&:integration_id)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    integration = Integration.find(params[:id])
    integration.destroy!
    redirect_to integrations_path, notice: "#{integration.name} retiré : plus personne ne peut l'utiliser depuis SG Mail."
  end
end
