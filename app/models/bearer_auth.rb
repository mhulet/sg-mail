# Retrouve la personne et le client derrière un en-tête « Authorization: Bearer … » :
# jeton personnel (sgm_…) ou jeton OAuth d'un connecteur Claude (sgma_…).
# Un jeton dont la personne a quitté le client ne donne plus accès à rien.
module BearerAuth
  def self.membership_for(request)
    secret = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    token = ApiToken.authenticate(secret) || Oauth::Token.authenticate(secret)
    return unless token

    membership = Membership.includes(:account, :user).find_by(account_id: token.account_id, user_id: token.user_id)
    token.touch_last_used if membership
    membership
  end
end
