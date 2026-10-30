# Retrouve la personne et le client derrière un en-tête « Authorization: Bearer … » :
# jeton personnel (sgm_…) ou jeton OAuth d'un connecteur Claude (sgma_…).
# Un jeton dont la personne a quitté le client ne donne plus accès à rien.
module BearerAuth
  # Pour l'API : un seul client. Un connecteur qui couvre tous les clients n'y donne pas accès.
  def self.membership_for(request)
    token = token_for(request)
    memberships_for_token(token).first if token&.account_id
  end

  # Pour le MCP : les clients que couvre le jeton, par nom. Un connecteur sans client couvre tous ceux
  # de la personne, y compris ceux qu'elle rejoint plus tard.
  def self.memberships_for(request)
    memberships_for_token(token_for(request))
  end

  def self.token_for(request)
    secret = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    ApiToken.authenticate(secret) || Oauth::Token.authenticate(secret)
  end

  def self.memberships_for_token(token)
    return [] unless token

    memberships = Membership.includes(:account, :user).where(user_id: token.user_id)
    memberships = memberships.where(account_id: token.account_id) if token.account_id
    memberships.sort_by { |membership| membership.account.name }.tap { |found| token.touch_last_used if found.any? }
  end
  private_class_method :memberships_for_token
end
