# Un libellé court (« Formations », « Perso ») affiché à la place de l'adresse complète.
class AddLabelToMailboxes < ActiveRecord::Migration[8.1]
  def change
    add_column :mailboxes, :label, :string
  end
end
