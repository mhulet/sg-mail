# L'agent intégré (note sg-mail-agent, étape 1) : un agent par personne (prénom, couleur, style), éteint par
# défaut et activé client par client, des discussions avec lui, et le journal de chaque outil qu'il appelle.
class CreateAgents < ActiveRecord::Migration[8.1]
  TABLES = %w[agent_chats agent_messages agent_actions].freeze

  def up
    # Rattaché à une personne, pas à un client (le même agent dans tous ses clients) : pas de Row Level Security.
    create_table :agents do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :name, null: false
      t.string :color, null: false
      t.string :style, null: false
      t.text :instructions
      t.timestamps
    end

    add_column :accounts, :agent_enabled, :boolean, null: false, default: false
    add_column :accounts, :agent_monthly_budget_cents, :integer, null: false, default: 2000

    create_table :agent_chats do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.string :title
      t.string :status, null: false, default: "idle"
      t.text :error
      t.timestamps
    end
    add_index :agent_chats, %i[user_id updated_at]

    create_table :agent_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent_chat, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      # Les blocs de contenu tels que Claude les rend ou les attend (texte, outils, résultats, réflexion).
      t.jsonb :content, null: false, default: []
      t.string :model
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      # Coût en millionièmes de dollar, pour le suivi et le plafond mensuel du client.
      t.integer :cost_micros, null: false, default: 0
      t.timestamps
    end
    add_index :agent_messages, %i[account_id created_at]

    create_table :agent_actions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :agent_chat, null: false, foreign_key: { on_delete: :cascade }
      t.references :agent_message, null: false, foreign_key: { on_delete: :cascade }
      t.string :tool_use_id, null: false
      t.string :tool_name, null: false
      t.jsonb :input, null: false, default: {}
      t.boolean :writes, null: false, default: false
      t.string :status, null: false, default: "pending"
      t.jsonb :result
      t.references :decided_by, foreign_key: { to_table: :users }
      t.datetime :decided_at
      t.timestamps
    end

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
    drop_table :agent_actions
    drop_table :agent_messages
    drop_table :agent_chats
    remove_column :accounts, :agent_monthly_budget_cents
    remove_column :accounts, :agent_enabled
    drop_table :agents
  end
end
