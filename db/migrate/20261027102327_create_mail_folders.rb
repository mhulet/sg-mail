class CreateMailFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_folders do |t|
      t.references :mailbox, null: false, foreign_key: true
      t.string :name, null: false
      t.bigint :uidvalidity
      t.bigint :last_uid, null: false, default: 0
      t.timestamps
    end
    add_index :mail_folders, [ :mailbox_id, :name ], unique: true
  end
end
