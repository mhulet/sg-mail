# Qui voit quelle boîte : une boîte perso n'a qu'un accès, une boîte partagée en a plusieurs.
class CreateMailboxAccesses < ActiveRecord::Migration[8.1]
  def up
    create_table :mailbox_accesses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :mailbox, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :level, null: false, default: "send"
      t.timestamps
    end
    add_index :mailbox_accesses, %i[mailbox_id user_id], unique: true

    add_reference :mailboxes, :connected_by, foreign_key: { to_table: :users }

    # Les boîtes existantes (phase 0) sont confiées aux admins de leur client.
    execute "SET sg_mail.bypass_rls = 'on'"
    execute <<~SQL
      INSERT INTO mailbox_accesses (account_id, mailbox_id, user_id, level, created_at, updated_at)
      SELECT mailboxes.account_id, mailboxes.id, memberships.user_id, 'manage', now(), now()
      FROM mailboxes JOIN memberships ON memberships.account_id = mailboxes.account_id AND memberships.role = 'admin'
    SQL
    execute "RESET sg_mail.bypass_rls"

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    execute <<~SQL
      ALTER TABLE mailbox_accesses ENABLE ROW LEVEL SECURITY;
      ALTER TABLE mailbox_accesses FORCE ROW LEVEL SECURITY;
      CREATE POLICY account_isolation ON mailbox_accesses USING (#{condition}) WITH CHECK (#{condition});
    SQL
  end

  def down
    remove_reference :mailboxes, :connected_by, foreign_key: { to_table: :users }
    drop_table :mailbox_accesses
  end
end
