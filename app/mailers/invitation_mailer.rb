class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail subject: "#{invitation.invited_by.display_name} t'invite sur SG Mail (#{invitation.account.name})", to: invitation.email_address
  end
end
