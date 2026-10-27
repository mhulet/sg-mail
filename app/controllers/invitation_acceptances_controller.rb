# Lien reçu par email : on rejoint le client avec son compte, ou on en crée un.
class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_invitation

  def show
    @user = User.new(email_address: @invitation.email_address)
  end

  def create
    if authenticated?
      accept_as Current.user
    elsif User.exists?(email_address: @invitation.email_address)
      session[:return_to_after_authenticating] = invitation_acceptance_url(@invitation.token)
      redirect_to new_session_path, notice: "Tu as déjà un compte SG Mail : connecte-toi pour rejoindre « #{@invitation.account.name} »."
    else
      @user = User.new(params.expect(user: %i[name password password_confirmation]).merge(email_address: @invitation.email_address))
      if @user.save
        start_new_session_for @user
        accept_as @user
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_pending_by_token(params[:token])
    redirect_to root_path, alert: "Cette invitation n'est plus valable." unless @invitation
  end

  def accept_as(user)
    @invitation.accept!(user)
    redirect_to account_root_path(account_id: @invitation.account_id), notice: "Bienvenue dans « #{@invitation.account.name} »."
  end
end
