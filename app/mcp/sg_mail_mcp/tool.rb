# Base des outils : erreurs lisibles pour Claude et sortie JSON. Les sous-classes implémentent
# `perform(actions, serializer, **arguments)` et rendent un Hash.
#
# Un connecteur peut couvrir plusieurs clients (SgMailMcp::Accounts) : chaque outil accepte alors account_id,
# déclare les arguments qui désignent un élément d'un client (locates) ou rassemble les résultats de tous
# les clients (aggregates!).
class SgMailMcp::Tool < MCP::Tool
  ACCOUNT_ID = { type: "integer", description: "Organisation (account id from whoami). Only needed when I belong to several" }.freeze

  class << self
    def read_only!
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)
    end

    def writes!(idempotent: false, open_world: false)
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: idempotent, open_world_hint: open_world)
    end

    def input_schema(*args)
      args[0] = args[0].merge(properties: args[0].fetch(:properties, {}).merge(account_id: ACCOUNT_ID)) if args[0].is_a?(Hash)
      super
    end

    # Les arguments qui désignent un élément, et son modèle : l'outil s'exécute dans le client de cet élément.
    def locates(**models) = @locators = models
    def locators = @locators || {}

    # Sans élément désigné, l'outil s'exécute dans chaque client et combine les résultats.
    def aggregates! = @aggregates = true
    def aggregates? = @aggregates || false

    # Par défaut, les listes de chaque client mises bout à bout, chaque élément avec son client.
    def combine(results, **)
      results.each_with_object({}) do |(account, result), combined|
        result.each { |key, items| (combined[key] ||= []).concat(items.map { |item| { account: account }.merge(item) }) }
      end
    end

    def call(server_context:, **arguments)
      account_id = arguments.delete(:account_id)
      run = ->(args) { perform(server_context[:actions], server_context[:serializer], **args) }
      result = if server_context[:accounts]
        server_context[:accounts].run(self, account_id, arguments, &run)
      else
        check_account!(account_id)
        run.(arguments)
      end
      MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(result) } ], structured_content: result)
    rescue ArgumentError, ActiveRecord::RecordNotFound => error
      error_response(error.is_a?(ActiveRecord::RecordNotFound) ? "Introuvable ou inaccessible : #{error.model} #{error.id}".strip : error.message)
    rescue ActiveRecord::RecordInvalid => error
      error_response(error.record.errors.full_messages.to_sentence)
    end

    private

    def perform(...)
      raise NotImplementedError
    end

    # Un jeton d'un seul client : account_id ne peut viser que celui-là.
    def check_account!(account_id)
      account = ActsAsTenant.current_tenant
      return if account_id.blank? || account.nil? || account_id.to_i == account.id

      raise ArgumentError, "Ce connecteur ne donne accès qu'au client #{account.name} (account_id #{account.id})"
    end

    def error_response(message) = MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
  end
end
