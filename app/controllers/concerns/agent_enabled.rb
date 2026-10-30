# Contrôleurs de l'agent : seulement dans un client où un admin l'a activé (décision A7).
module AgentEnabled
  extend ActiveSupport::Concern

  included do
    before_action :require_agent_enabled
  end

  private

  def require_agent_enabled
    redirect_to agent_settings_path, alert: "L'agent n'est pas activé pour #{current_account.name}." unless current_account.agent_enabled?
  end
end
