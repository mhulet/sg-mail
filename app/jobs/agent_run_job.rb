# L'agent répond en tâche de fond ; la page de la discussion se rafraîchit à chaque étape.
class AgentRunJob < ApplicationJob
  queue_as :default

  # resume : après la confirmation ou le refus des actions en attente.
  def perform(chat, resume: false)
    Tenancy.with_account(chat.account) do
      run = AgentRun.new(chat.reload)
      resume ? run.resume : run.perform
    end
  end
end
