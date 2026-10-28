# Imbox / Feed / Paper Trail, façon Hey : chaque expéditeur accepté est rangé, par personne,
# dans la réception, le Feed (lettres d'info, lectures) ou le Paper Trail (reçus, notifications).
class AddBucketToScreenings < ActiveRecord::Migration[8.1]
  def change
    add_column :screenings, :bucket, :string, null: false, default: "imbox"
  end
end
