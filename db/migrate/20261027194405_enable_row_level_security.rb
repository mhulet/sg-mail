# Deuxième verrou de l'isolation des clients (décision D3) : même si l'application oublie un filtre,
# Postgres ne rend que les lignes du client fixé sur la connexion (voir Tenancy).
# FORCE applique aussi les règles au propriétaire des tables ; seul un superutilisateur y échappe.
class EnableRowLevelSecurity < ActiveRecord::Migration[8.1]
  TABLES = %w[mailboxes mail_folders messages].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY account_isolation ON #{table}
          USING (#{condition}) WITH CHECK (#{condition});
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute <<~SQL
        DROP POLICY account_isolation ON #{table};
        ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;
      SQL
    end
  end

  private

  def condition
    "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
  end
end
