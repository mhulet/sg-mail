# Journal d'accès (cadrage §4.2) : qui a ouvert quel fil ou téléchargé quelle pièce jointe, quand, et par où
# (interface, API, MCP). Gardé un an.
class CreateAccessLogs < ActiveRecord::Migration[8.1]
  def up
    create_table :access_logs do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :message, foreign_key: { on_delete: :nullify }, index: false
      t.string :action, null: false
      t.string :via, null: false
      t.string :detail
      t.datetime :created_at, null: false
    end
    add_index :access_logs, %i[account_id created_at]

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    execute <<~SQL
      ALTER TABLE access_logs ENABLE ROW LEVEL SECURITY;
      ALTER TABLE access_logs FORCE ROW LEVEL SECURITY;
      CREATE POLICY account_isolation ON access_logs USING (#{condition}) WITH CHECK (#{condition});
    SQL
  end

  def down
    drop_table :access_logs
  end
end
