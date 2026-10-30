# Mes discussions avec mon agent dans ce client. Personne d'autre ne les voit, pas même les admins.
class AgentChatsController < ApplicationController
  include AccountScoped
  include AgentEnabled

  def index
    @chats = my_chats.recent.includes(:conversation).limit(100)
    @agent = Agent.for(Current.user)
  end

  def show
    @chat = my_chats.find(params[:id])
    @agent = Agent.for(Current.user)
  end

  # Une nouvelle discussion, depuis un fil (conversation_id) ou non, avec son premier message.
  def create
    conversation = Conversation.accessible_by(Current.user).find(params[:conversation_id]) if params[:conversation_id].present?
    chat = my_chats.create!(conversation: conversation)
    chat.ask!(params[:prompt].presence || params[:text])
    redirect_to conversation ? conversation_path(conversation, anchor: "agent") : agent_chat_path(chat)
  rescue ArgumentError => e
    chat&.destroy
    redirect_back fallback_location: agent_chats_path, alert: e.message
  end

  private

  def my_chats = AgentChat.where(user: Current.user)
end
