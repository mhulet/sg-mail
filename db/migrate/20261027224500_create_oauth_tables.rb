# Serveur d'autorisation OAuth 2.1 du MCP, pour ajouter SG Mail comme connecteur dans claude.ai.
# Hors RLS, comme les sessions : les jetons sont retrouvés avant de connaître le client.
# Codes et jetons ne sont jamais stockés en clair, seulement leur empreinte SHA-256.
class CreateOauthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :uid, null: false, index: { unique: true }
      t.string :name, null: false
      t.jsonb :redirect_uris, null: false, default: []
      t.timestamps
    end

    create_table :oauth_authorization_codes do |t|
      t.references :oauth_client, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false, index: { unique: true }
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :resource
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    create_table :oauth_tokens do |t|
      t.references :oauth_client, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :access_token_digest, null: false, index: { unique: true }
      t.string :refresh_token_digest, null: false, index: { unique: true }
      t.datetime :access_expires_at, null: false
      t.datetime :refresh_expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
