class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :mailbox, null: false, foreign_key: true
      t.references :mail_folder, foreign_key: true
      t.string :provider_uid, null: false
      t.string :thread_key
      t.string :message_id_header
      t.string :subject
      t.string :from_address
      t.string :from_name
      t.jsonb :to_addresses, null: false, default: []
      t.jsonb :cc_addresses, null: false, default: []
      t.datetime :sent_at
      t.text :snippet
      t.text :body_text
      t.text :body_html
      t.jsonb :labels, null: false, default: []
      t.integer :size
      t.boolean :has_attachments, null: false, default: false
      t.timestamps
    end
    add_index :messages, [ :mailbox_id, :provider_uid ], unique: true
    add_index :messages, [ :mailbox_id, :thread_key ]
    add_index :messages, [ :mailbox_id, :sent_at ]
  end
end
