# Jetons personnels pour l'API et le CLI. Comme les sessions, hors RLS : on les retrouve
# avant de connaître le client. Seule l'empreinte SHA-256 du jeton est gardée.
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
