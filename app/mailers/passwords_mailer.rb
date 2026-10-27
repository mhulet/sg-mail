class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Nouveau mot de passe SG Mail", to: user.email_address
  end
end
