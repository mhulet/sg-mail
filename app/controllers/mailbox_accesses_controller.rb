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

    if level.nil? && @mailbox.accesses.where(level: "manage").where.not(user: user).none?
      redirect_to mailbox_accesses_path(@mailbox), alert: "Il faut garder au moins une personne qui gère la boîte."
    elsif level.nil?
      @mailbox.accesses.where(user: user).delete_all
      redirect_to mailbox_accesses_path(@mailbox), notice: "#{user.display_name} n'a plus accès à #{@mailbox.address}."
    elsif level != "manage" && @mailbox.access_for(user)&.can_manage? && @mailbox.accesses.where(level: "manage").count == 1
      redirect_to mailbox_accesses_path(@mailbox), alert: "Il faut garder au moins une personne qui gère la boîte."
    else
      @mailbox.grant!(user, level)
      redirect_to mailbox_accesses_path(@mailbox), notice: "#{user.display_name} : #{MailboxAccess::LABELS.fetch(level).downcase}."
    end
  rescue KeyError, ActiveRecord::RecordInvalid
    redirect_to mailbox_accesses_path(@mailbox), alert: "Niveau d'accès inconnu."
  end

  private

  def set_mailbox
    @mailbox = Mailbox.accessible_by(Current.user).find(params[:mailbox_id])
    redirect_to @mailbox, alert: "Il faut le droit de gestion sur cette boîte." unless @mailbox.access_for(Current.user).can_manage?
  end
end
