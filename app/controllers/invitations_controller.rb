class InvitationsController < ApplicationController
  include AccountScoped
  before_action :require_admin

  def create
    invitation = current_account.invitations.build(params.expect(invitation: %i[email_address role]).merge(invited_by: Current.user))

    if invitation.save
      InvitationMailer.invite(invitation).deliver_later
      redirect_to memberships_path, notice: "Invitation envoyée à #{invitation.email_address}."
    else
      redirect_to memberships_path, alert: "Invitation impossible : #{invitation.errors.full_messages.to_sentence}"
    end
  end

  def destroy
    current_account.invitations.find(params[:id]).destroy!
    redirect_to memberships_path, notice: "Invitation annulée."
  end
end
