class AddSendAtToDrafts < ActiveRecord::Migration[8.1]
  def change
    # L'heure d'envoi prévue : dans quelques secondes (le temps d'annuler) ou plus tard (« Envoyer plus tard »).
    add_column :drafts, :send_at, :datetime
  end
end
