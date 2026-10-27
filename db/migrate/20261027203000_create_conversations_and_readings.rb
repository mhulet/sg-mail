# Fils de discussion (regroupés par boîte) et statut de lecture par personne (« lu par… »).
class CreateConversationsAndReadings < ActiveRecord::Migration[8.1]
  TABLES = %w[conversations readings].freeze

  def up
    create_table :conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :mailbox, null: false, foreign_key: true
      t.string :thread_key, null: false
      t.string :subject
      t.string :last_sender
      t.text :snippet
      t.datetime :last_message_at
      t.integer :messages_count, null: false, default: 0
      t.boolean :in_inbox, null: false, default: false
      t.timestamps
    end
    add_index :conversations, %i[mailbox_id thread_key], unique: true
    add_index :conversations, %i[account_id last_message_at]

    add_reference :messages, :conversation, foreign_key: true
    add_column :messages, :attachments, :jsonb, null: false, default: []

    create_table :readings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.datetime :read_at, null: false
    end
    add_index :readings, %i[message_id user_id], unique: true
    add_index :readings, %i[user_id message_id]

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    TABLES.each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY account_isolation ON #{table} USING (#{condition}) WITH CHECK (#{condition});
      SQL
    end
  end

  def down
    drop_table :readings
    remove_column :messages, :attachments
    remove_reference :messages, :conversation, foreign_key: true
    drop_table :conversations
  end
end
