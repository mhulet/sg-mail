# Un connecteur Claude peut couvrir tous les clients de la personne : account_id vide.
class AllowOauthTokensForAllAccounts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :oauth_tokens, :account_id, true
    change_column_null :oauth_authorization_codes, :account_id, true
  end
end
