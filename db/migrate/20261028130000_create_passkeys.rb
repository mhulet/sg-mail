# Connexion par passkey (cadrage §8), en plus du mot de passe. Les utilisateurs ne sont pas rattachés
# à un client : pas de Row Level Security ici.
class CreatePasskeys < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true

    create_table :passkeys do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.string :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :name, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :passkeys, :external_id, unique: true
  end
end
