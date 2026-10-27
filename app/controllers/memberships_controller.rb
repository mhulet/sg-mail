class MembershipsController < ApplicationController
  include AccountScoped
  before_action :require_admin, only: :update
  before_action :set_membership, only: %i[update destroy]

  def index
    @memberships = current_account.memberships.includes(:user).order(:role, :created_at)
    @invitations = current_account.invitations.pending.order(:created_at)
    @invitation = current_account.invitations.build
  end

  def update
    if @membership.update(role: params.dig(:membership, :role))
      redirect_to memberships_path, notice: "#{@membership.user.display_name} est maintenant #{@membership.role_label.downcase}."
    else
      redirect_to memberships_path, alert: @membership.errors.full_messages.to_sentence
    end
  end

  # Un admin retire quelqu'un ; chacun peut aussi quitter le client.
  def destroy
    leaving = @membership == current_membership
    return require_admin unless leaving || current_membership.admin?

    if !@membership.destroy
      redirect_to memberships_path, alert: @membership.errors.full_messages.to_sentence
    elsif leaving
      redirect_to accounts_path(account_id: nil), notice: "Tu as quitté « #{current_account.name} »."
    else
      redirect_to memberships_path, notice: "#{@membership.user.display_name} ne fait plus partie du client."
    end
  end

  private

  def set_membership
    @membership = current_account.memberships.find(params[:id])
  end
end
