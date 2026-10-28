class Api::V1::ConversationsController < Api::V1::BaseController
  # Paramètres : q, box (imbox, feed, paper_trail), stack (reply_later, set_aside), mailbox_id, unread=1, mine=1,
  # before (date ISO 8601), limit.
  def index
    conversations = actions.conversations(query: params[:q], box: params[:box], stack: params[:stack], mailbox_id: params[:mailbox_id], unread: params[:unread] == "1",
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

  # Paramètres (chacun facultatif) : assignee_id (vide pour personne), reply_later et set_aside (true ou false).
  def update
    actions.assign(params[:id], params[:assignee_id]) if params.key?(:assignee_id)
    stacks = %i[reply_later set_aside].index_with { |key| ActiveModel::Type::Boolean.new.cast(params[key]) if params.key?(key) }
    render json: { conversation: serializer.conversation(actions.update_stacks(params[:id], **stacks)) }
  end
end
