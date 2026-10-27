# Isolation des clients (décision D3), voir Tenancy.
ActsAsTenant.configure do |config|
  # Une requête sur une table d'un client sans client fixé lève une erreur au lieu de tout renvoyer.
  config.require_tenant = true
  # Le client courant est recopié sur la connexion Postgres pour la Row Level Security.
  config.tenant_change_hook = ->(account) { Tenancy.apply_account(account) }
end

# Une connexion qui sort du pool ne garde jamais le client de la requête précédente.
ActiveSupport.on_load(:active_record_postgresqladapter) do
  set_callback :checkout, :after, -> { Tenancy.reset(self) }
end
