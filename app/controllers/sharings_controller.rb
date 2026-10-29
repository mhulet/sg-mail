# Partage global d'un client : qui a accès à quelles boîtes, en un coup d'œil (membres × boîtes).
# Mêmes règles que la page de partage d'une boîte : on n'y voit et n'y change que les boîtes qu'on gère.
class SharingsController < ApplicationController
  include AccountScoped

  def show
    @mailboxes = Mailbox.managed_by(Current.user).order(:address)
    @memberships = current_account.memberships.includes(:user).order(:created_at)
    @levels = MailboxAccess.where(mailbox: @mailboxes).pluck(:mailbox_id, :user_id, :level).to_h { |mailbox_id, user_id, level| [ [ mailbox_id, user_id ], level ] }
    @unmanaged_count = Mailbox.accessible_by(Current.user).count - @mailboxes.size
  end

  # level vide = retirer l'accès.
  def update
    mailbox = Mailbox.managed_by(Current.user).find(params[:mailbox_id])
    user = current_account.users.find(params[:user_id])
    level = params[:level].presence
    mailbox.change_access!(user, level)
    redirect_to sharing_path, notice: MailboxAccess.change_notice(user, mailbox, level)
  rescue Mailbox::LastManagerError => e
    redirect_to sharing_path, alert: e.message
  rescue ActiveRecord::RecordInvalid
    redirect_to sharing_path, alert: "Niveau d'accès inconnu."
  end
end
