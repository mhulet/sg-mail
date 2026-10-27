# Base des outils : erreurs lisibles pour Claude et sortie JSON. Les sous-classes implémentent
# `perform(actions, serializer, **arguments)` et rendent un Hash.
class SgMailMcp::Tool < MCP::Tool
  class << self
    def read_only!
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)
    end

    def writes!(idempotent: false, open_world: false)
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: idempotent, open_world_hint: open_world)
    end

    def call(server_context:, **arguments)
      result = perform(server_context[:actions], server_context[:serializer], **arguments)
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

    def error_response(message) = MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
  end
end
