class Api::V1::NotesController < Api::V1::BaseController
  def create
    note = actions.add_note(params[:conversation_id], params.require(:body))
    render json: { note: serializer.note(note) }, status: :created
  end
end
