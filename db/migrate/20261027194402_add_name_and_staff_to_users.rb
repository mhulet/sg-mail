class AddNameAndStaffToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false, default: ""
    # Équipe Super Génial : peut créer des clients, sans voir leurs emails.
    add_column :users, :staff, :boolean, null: false, default: false
  end
end
