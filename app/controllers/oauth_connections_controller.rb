# Connecteurs Claude autorisés dans ce client : on peut les déconnecter.
class OauthConnectionsController < ApplicationController
  include AccountScoped

  # Révoque tous les jetons de ce connecteur pour moi dans ce client.
  def destroy
    tokens = Oauth::Token.active.where(user: Current.user, account: Current.account, oauth_client_id: params[:id])
    tokens.find_each(&:revoke!)
    redirect_to api_tokens_path, notice: "Connecteur déconnecté."
  end
end
