# Notifications Web Push (iPhone avec SG Mail sur l'écran d'accueil, Android, ordinateur) : un abonnement
# par appareil et par navigateur. Rattaché à une personne, pas à un client : pas de Row Level Security ici.
class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true
  end
end
