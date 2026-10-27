# Travail à plusieurs sur un fil : tâches nées des emails, notes internes, et qui s'occupe du fil.
class CreateTasksAndNotes < ActiveRecord::Migration[8.1]
  TABLES = %w[tasks notes].freeze

  def up
    create_table :tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :message, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.date :due_on
      t.datetime :completed_at
      # Lien vers la tâche créée ailleurs (MySemisto…), renseigné par Claude via le MCP.
      t.string :external_ref
      t.timestamps
    end
    add_index :tasks, %i[assignee_id status]

    create_table :notes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    add_reference :conversations, :assignee, foreign_key: { to_table: :users }

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
    remove_reference :conversations, :assignee, foreign_key: { to_table: :users }
    drop_table :notes
    drop_table :tasks
  end
end
