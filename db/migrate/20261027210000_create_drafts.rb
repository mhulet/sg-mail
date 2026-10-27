# Messages qu'on rédige (nouveau, réponse, transfert), puis qu'on envoie depuis une boîte.
class CreateDrafts < ActiveRecord::Migration[8.1]
  def up
    create_table :drafts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :mailbox, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :source_message, foreign_key: { to_table: :messages, on_delete: :nullify }
      t.string :kind, null: false, default: "new"
      t.jsonb :to_addresses, null: false, default: []
      t.jsonb :cc_addresses, null: false, default: []
      t.jsonb :bcc_addresses, null: false, default: []
      t.string :subject
      t.text :body
      t.string :status, null: false, default: "draft"
      t.text :error
      t.datetime :sent_at
      t.timestamps
    end

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    execute <<~SQL
      ALTER TABLE drafts ENABLE ROW LEVEL SECURITY;
      ALTER TABLE drafts FORCE ROW LEVEL SECURITY;
      CREATE POLICY account_isolation ON drafts USING (#{condition}) WITH CHECK (#{condition});
    SQL
  end

  def down
    drop_table :drafts
  end
end
