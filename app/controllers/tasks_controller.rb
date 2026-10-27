class TasksController < ApplicationController
  include AccountScoped
  before_action :set_task, only: %i[update destroy]

  # « Mes tâches » : à faire d'abord (par échéance), puis les dernières terminées.
  def index
    tasks = Task.visible_to(Current.user).for_user(Current.user).includes(:conversation, :assignee)
    @open_tasks = tasks.open.by_due_date
    @done_tasks = tasks.done.order(completed_at: :desc).limit(20)
    @task = Task.new
    @members = current_account.users.order(:name)
  end

  def create
    @task = Task.new(task_params.merge(creator: Current.user))
    if (message_id = params.dig(:task, :message_id)).present?
      @task.message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find(message_id)
    elsif (conversation_id = params.dig(:task, :conversation_id)).present?
      @task.conversation = Conversation.accessible_by(Current.user).find(conversation_id)
    end

    if @task.save
      redirect_back_or_to tasks_path, notice: "Tâche créée."
    else
      redirect_back_or_to tasks_path, alert: "Tâche impossible : #{@task.errors.full_messages.to_sentence}"
    end
  end

  def update
    case params[:status]
    when "done" then @task.complete!
    when "open" then @task.reopen!
    else
      return redirect_back_or_to(tasks_path, alert: @task.errors.full_messages.to_sentence) unless @task.update(task_params)
    end
    redirect_back_or_to tasks_path
  end

  def destroy
    @task.destroy!
    redirect_back_or_to tasks_path, notice: "Tâche supprimée."
  end

  private

  def set_task
    @task = Task.visible_to(Current.user).find(params[:id])
  end

  def task_params
    params.fetch(:task, {}).permit(:title, :due_on, :assignee_id)
  end
end
