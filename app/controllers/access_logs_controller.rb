# Journal d'accès du client, pour ses admins : qui a ouvert quoi, quand, et par où.
class AccessLogsController < ApplicationController
  include AccountScoped
  before_action :require_admin
  PER_PAGE = 200

  def index
    @people = current_account.users.order(:name)
    logs = AccessLog.recent.includes(:user, :message, conversation: :mailbox)
    logs = logs.where(user_id: params[:user_id]) if params[:user_id].present?
    logs = logs.where(created_at: ...Time.zone.parse(params[:before])) if params[:before].present?
    @logs = logs.limit(PER_PAGE).to_a
  end
end
