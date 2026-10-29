# Partage d'une boîte : qui y a accès, et à quel niveau. Réservé à ceux qui la gèrent.
class MailboxAccessesController < ApplicationController
  include AccountScoped
  before_action :set_mailbox

  def index
    @accesses = @mailbox.accesses.includes(:user).index_by(&:user_id)
    @memberships = current_account.memberships.includes(:user).order(:created_at)
  end

  # level vide = retirer l'accès.
  def update
    user = current_account.users.find(params[:id])
    level = params[:level].presence
    @mailbox.change_access!(user, level)
    redirect_to mailbox_accesses_path(@mailbox), notice: MailboxAccess.change_notice(user, @mailbox, level)
  rescue Mailbox::LastManagerError => e
    redirect_to mailbox_accesses_path(@mailbox), alert: e.message
  rescue ActiveRecord::RecordInvalid
    redirect_to mailbox_accesses_path(@mailbox), alert: "Niveau d'accès inconnu."
  end

  private

  def set_mailbox
    @mailbox = Mailbox.accessible_by(Current.user).find(params[:mailbox_id])
    redirect_to @mailbox, alert: "Il faut le droit de gestion sur cette boîte." unless @mailbox.access_for(Current.user).can_manage?
  end
end
