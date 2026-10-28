# Screener, façon Hey : chaque personne décide, pour elle seule, si un nouvel expéditeur entre dans
# sa réception ou en reste dehors. Le fil retient l'expéditeur qui l'a ouvert.
class CreateScreenings < ActiveRecord::Migration[8.1]
  def up
    create_table :screenings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :address, null: false
      t.string :decision, null: false
      t.timestamps
    end
    add_index :screenings, %i[user_id account_id address], unique: true

    add_column :conversations, :sender_address, :string
    add_column :conversations, :sender_name, :string
    add_index :conversations, %i[mailbox_id sender_address]

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    execute <<~SQL
      ALTER TABLE screenings ENABLE ROW LEVEL SECURITY;
      ALTER TABLE screenings FORCE ROW LEVEL SECURITY;
      CREATE POLICY account_isolation ON screenings USING (#{condition}) WITH CHECK (#{condition});
    SQL

    # Les fils existants et leurs expéditeurs : tout l'historique est accepté d'office,
    # pour ne pas ouvrir le Screener sur des centaines de noms.
    execute "SET LOCAL sg_mail.bypass_rls = 'on'"
    execute <<~SQL
      UPDATE conversations SET sender_address = first_inbound.address, sender_name = first_inbound.name
      FROM (
        SELECT DISTINCT ON (messages.conversation_id) messages.conversation_id,
          lower(messages.from_address) AS address, NULLIF(messages.from_name, '') AS name
        FROM messages JOIN mailboxes ON mailboxes.id = messages.mailbox_id
        WHERE messages.conversation_id IS NOT NULL AND messages.from_address IS NOT NULL
          AND lower(messages.from_address) <> lower(mailboxes.address)
        ORDER BY messages.conversation_id, messages.sent_at NULLS LAST, messages.id
      ) AS first_inbound
      WHERE conversations.id = first_inbound.conversation_id
    SQL
    execute <<~SQL
      INSERT INTO screenings (account_id, user_id, address, decision, created_at, updated_at)
      SELECT DISTINCT messages.account_id, mailbox_accesses.user_id, lower(messages.from_address), 'accepted', now(), now()
      FROM messages
      JOIN mailboxes ON mailboxes.id = messages.mailbox_id
      JOIN mailbox_accesses ON mailbox_accesses.mailbox_id = messages.mailbox_id
      WHERE messages.from_address IS NOT NULL AND lower(messages.from_address) <> lower(mailboxes.address)
      ON CONFLICT DO NOTHING
    SQL
    # Les personnes à qui une boîte a écrit sont acceptées aussi.
    execute <<~SQL
      INSERT INTO screenings (account_id, user_id, address, decision, created_at, updated_at)
      SELECT DISTINCT messages.account_id, mailbox_accesses.user_id, lower(recipient.address), 'accepted', now(), now()
      FROM messages
      JOIN mailboxes ON mailboxes.id = messages.mailbox_id
      JOIN mailbox_accesses ON mailbox_accesses.mailbox_id = messages.mailbox_id
      CROSS JOIN LATERAL jsonb_array_elements_text(messages.to_addresses || messages.cc_addresses) AS recipient(address)
      WHERE lower(messages.from_address) = lower(mailboxes.address)
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    remove_index :conversations, %i[mailbox_id sender_address]
    remove_column :conversations, :sender_name
    remove_column :conversations, :sender_address
    drop_table :screenings
  end
end
