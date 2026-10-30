# Confirmer ou refuser ce que l'agent veut faire (décision A3).
class AgentActionsController < AgentMessagesController
  def update
    chat = AgentChat.where(user: Current.user).find(params[:agent_chat_id])
    action = chat.agent_actions.find(params[:id])
    chat.decide!(action, confirm: params[:decision] == "confirm", user: Current.user)
    redirect_to back_to(chat)
  rescue ArgumentError => e
    redirect_to back_to(chat), alert: e.message
  end
end
