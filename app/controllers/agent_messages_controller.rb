class AgentMessagesController < ApplicationController
  include AccountScoped
  include AgentEnabled

  def create
    chat = AgentChat.where(user: Current.user).find(params[:agent_chat_id])
    chat.ask!(params[:prompt].presence || params[:text])
    redirect_to back_to(chat)
  rescue ArgumentError => e
    redirect_to back_to(chat), alert: e.message
  end

  private

  # Le panneau d'un fil revient au fil, la discussion plein écran à elle-même.
  def back_to(chat) = params[:from_conversation].present? && chat.conversation ? conversation_path(chat.conversation, anchor: "agent") : agent_chat_path(chat)
end
