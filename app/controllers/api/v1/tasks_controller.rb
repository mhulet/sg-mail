class Api::V1::TasksController < Api::V1::BaseController
  # Paramètres : scope=mine|all, status=open|done|all, conversation_id, limit.
  def index
    tasks = actions.tasks(scope: params[:scope] || "mine", status: params[:status].presence || "open",
      conversation_id: params[:conversation_id], limit: params[:limit] || 100)
    render json: { tasks: tasks.map { |task| serializer.task(task) } }
  end

  def show
    render json: { task: serializer.task(actions.task(params[:id])) }
  end

  def create
    task = actions.create_task(title: params.require(:title), message_id: params[:message_id], conversation_id: params[:conversation_id],
      assignee_id: params.key?(:assignee_id) ? params[:assignee_id] : :me, due_on: params[:due_on], external_ref: params[:external_ref])
    render json: { task: serializer.task(task) }, status: :created
  end

  def update
    attributes = params.permit(:title, :due_on, :assignee_id, :external_ref).to_h.symbolize_keys
    render json: { task: serializer.task(actions.update_task(params[:id], status: params[:status], **attributes)) }
  end
end
