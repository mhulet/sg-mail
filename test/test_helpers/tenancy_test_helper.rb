# Un superutilisateur Postgres échappe à la Row Level Security : pour la voir à l'œuvre,
# les tests passent par un rôle ordinaire.
module TenancyTestHelper
  RESTRICTED_ROLE = "sg_mail_rls_test"

  def self.create_restricted_role
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      next unless connection.select_value("SELECT rolsuper FROM pg_roles WHERE rolname = current_user")

      connection.execute(<<~SQL)
        DO $$ BEGIN
          CREATE ROLE #{RESTRICTED_ROLE} NOLOGIN;
        EXCEPTION WHEN duplicate_object THEN NULL;
        END $$;
      SQL
    end
  end

  def with_restricted_database_role
    connection = ActiveRecord::Base.lease_connection
    skip "Il faut un superutilisateur Postgres pour tester la Row Level Security" unless connection.select_value("SELECT rolsuper FROM pg_roles WHERE rolname = current_user")

    connection.execute(<<~SQL)
      GRANT ALL ON ALL TABLES IN SCHEMA public TO #{RESTRICTED_ROLE};
      GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO #{RESTRICTED_ROLE};
      SET ROLE #{RESTRICTED_ROLE};
    SQL
    yield
  ensure
    connection&.execute("RESET ROLE")
  end

  def with_account(account, &block)
    Tenancy.with_account(account, &block)
  end
end

TenancyTestHelper.create_restricted_role
