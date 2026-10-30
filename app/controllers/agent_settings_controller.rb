# L'agent dans un client : activé ou non, plafond mensuel et dépense du mois (décisions A5 et A7).
# Tout le monde voit l'état ; seuls les admins le changent.
class AgentSettingsController < ApplicationController
  include AccountScoped
  before_action :require_admin, only: :update

  def show
    @agent = Agent.for(Current.user)
    @spend_cents = AgentRun.month_spend_cents
    @configured = AgentRun.configured?
  end

  def update
    budget = params.dig(:account, :agent_monthly_budget).to_s.tr(",", ".")
    attributes = { agent_enabled: params.dig(:account, :agent_enabled) == "1" }
    attributes[:agent_monthly_budget_cents] = (budget.to_d * 100).round.clamp(0, 1_000_000) if budget.present?
    current_account.update!(attributes)
    redirect_to agent_settings_path, notice: current_account.agent_enabled? ? "Agent activé pour #{current_account.name}." : "Agent désactivé pour #{current_account.name}."
  end
end
