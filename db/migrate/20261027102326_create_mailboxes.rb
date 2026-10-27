class CreateMailboxes < ActiveRecord::Migration[8.1]
  def change
    create_table :mailboxes do |t|
      t.string :provider, null: false
      t.string :address, null: false
      t.text :credentials
      t.jsonb :sync_state, null: false, default: {}
      t.datetime :last_synced_at
      t.text :last_sync_error
      t.timestamps
    end
    add_index :mailboxes, [ :provider, :address ], unique: true
  end
end
