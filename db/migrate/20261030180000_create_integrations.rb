# Les outils connectés (note sg-mail-agent, étape 2) : l'admin d'un client déclare un outil (son serveur MCP),
# chaque membre y connecte son propre compte, et l'agent en appelle les outils au nom de la personne.
class CreateIntegrations < ActiveRecord::Migration[8.1]
  TABLES = %w[integrations integration_connections].freeze

  def up
    create_table :integrations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      # Préfixe des noms d'outils pour Claude (« mysemisto__search »), tiré du nom.
      t.string :slug, null: false
      t.string :mcp_url, null: false
      t.timestamps
    end
    add_index :integrations, %i[account_id slug], unique: true

    create_table :integration_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :integration, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      # Le compte de la personne dans l'outil (m.hulet@semisto.org), sans lien avec son adresse SG Mail.
      t.string :remote_identity
      # Jetons OAuth, inscription du client SG Mail et autorisations en cours : JSON chiffré, jamais montré.
      t.text :oauth
      # Ce que le serveur dit de lui-même et ses outils, gardés pour ne pas les redemander à chaque question.
      t.text :instructions
      t.jsonb :tools, null: false, default: []
      t.datetime :tools_fetched_at
      t.datetime :connected_at
      t.timestamps
    end
    add_index :integration_connections, %i[integration_id user_id], unique: true

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
    drop_table :integration_connections
    drop_table :integrations
  end
end
