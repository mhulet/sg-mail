class Api::V1::ConversationsController < Api::V1::BaseController
  # Paramètres : q, mailbox_id, unread=1, mine=1, before (date ISO 8601), limit.
  def index
    conversations = actions.conversations(query: params[:q], mailbox_id: params[:mailbox_id], unread: params[:unread] == "1",
      mine: params[:mine] == "1", before: params[:before], limit: params[:limit] || 50)
    render json: { conversations: conversations.map { |conversation| serializer.conversation(conversation) } }
  end

  def show
    conversation = actions.conversation(params[:id], mark_read: params[:mark_read] == "1")
    render json: { conversation: serializer.conversation_detail(conversation, people: actions.people(conversation)) }
  end

  def read
    actions.mark_read(params[:id])
    head :no_content
  end

  def unread
    actions.mark_unread(params[:id])
    head :no_content
  end

  def update
    render json: { conversation: serializer.conversation(actions.assign(params[:id], params[:assignee_id])) }
  end
end
