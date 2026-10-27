# Isolation des clients (décision D3), en deux verrous :
# - acts_as_tenant filtre côté Rails les modèles qui appartiennent à un client (Mailbox, MailFolder, Message,
#   MailboxAccess…) ;
# - la Row Level Security de Postgres ne rend que les lignes du client fixé sur la connexion
#   (sg_mail.account_id), même si l'application oublie un filtre. Sans client fixé, rien n'est visible.
#
# Les tâches système qui traversent les clients (synchro récurrente, rake) passent par across_accounts.
# Une migration qui touche ces tables doit faire de même : `SET sg_mail.bypass_rls = 'on'`.
module Tenancy
  ACCOUNT_SETTING = "sg_mail.account_id"
  BYPASS_SETTING = "sg_mail.bypass_rls"

  module_function

  def with_account(account, &block)
    ActsAsTenant.with_tenant(account) { with_bypass("off", &block) }
  end

  def across_accounts(&block)
    ActsAsTenant.without_tenant { with_bypass("on", &block) }
  end

  def with_bypass(value)
    connection = ActiveRecord::Base.lease_connection
    previous = connection.uncached { connection.select_value("SELECT current_setting('#{BYPASS_SETTING}', true)") }
    set(connection, BYPASS_SETTING, value)
    yield
  ensure
    set(connection, BYPASS_SETTING, previous.to_s) if connection
  end

  # Appelé par acts_as_tenant à chaque changement de client courant.
  def apply_account(account)
    connection = account ? ActiveRecord::Base.lease_connection : ActiveRecord::Base.connection_pool.active_connection
    set(connection, ACCOUNT_SETTING, account&.id.to_s) if connection
  end

  def reset(connection)
    connection.execute("RESET #{ACCOUNT_SETTING}; RESET #{BYPASS_SETTING}")
  end

  # execute et pas select_value : le cache de requêtes ne doit jamais sauter un changement de réglage.
  def set(connection, name, value)
    connection.execute("SELECT set_config(#{connection.quote(name)}, #{connection.quote(value)}, false)")
  end
end
