# Brouillons : on rédige ici, l'envoi est une action séparée et explicite (deliver).
class Api::V1::DraftsController < Api::V1::BaseController
  def index
    render json: { drafts: actions.drafts(limit: params[:limit] || 50).map { |draft| serializer.draft(draft) } }
  end

  def show
    render json: { draft: serializer.draft(actions.draft(params[:id])) }
  end

  # message_id + kind (reply, reply_all, forward) pour répondre ; sinon un nouveau message.
  def create
    draft = actions.create_draft(message_id: params[:message_id], kind: params[:kind], mailbox_id: params[:mailbox_id],
      body: params[:body], **draft_fields)
    render json: { draft: serializer.draft(draft) }, status: :created
  end

  def update
    draft = actions.update_draft(params[:id], body: params.key?(:body) ? params[:body].to_s : nil, **draft_fields)
    render json: { draft: serializer.draft(draft) }
  end

  def deliver
    render json: { draft: serializer.draft(actions.deliver_draft(params[:id])) }, status: :accepted
  end

  private

  def draft_fields = params.permit(:subject, to: [], cc: [], bcc: []).to_h.symbolize_keys
end
