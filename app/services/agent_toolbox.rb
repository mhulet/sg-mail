# Les outils de l'agent : les mêmes que le serveur MCP de SG Mail, appelés en direct, au nom de la personne.
# Une lecture s'exécute tout de suite ; une écriture attend sa confirmation (décision A3). L'envoi d'un email
# n'en fait pas partie : l'agent prépare un brouillon, la personne l'envoie elle-même depuis SG Mail.
class AgentToolbox
  EXCLUDED = [ SgMailMcp::SendDraft ].freeze
  TOOLS = (SgMailMcp::TOOLS - EXCLUDED).index_by(&:name_value).freeze

  LABELS = {
    "mark_read" => "Marquer le fil comme lu", "mark_unread" => "Marquer le fil comme non lu", "assign" => "Assigner le fil",
    "add_note" => "Ajouter une note interne", "screen_sender" => "Trier un expéditeur", "update_stacks" => "Ranger le fil",
    "create_draft" => "Préparer un brouillon", "update_draft" => "Modifier un brouillon"
  }.freeze

  def self.label(name) = LABELS.fetch(name, name.to_s.humanize)

  def initialize(user, base_url: nil)
    @context = { actions: MailActions.new(user, via: "agent"), serializer: ApiSerializer.new(user: user, base_url: base_url) }
  end

  # Les définitions d'outils pour l'API Claude. L'agent travaille dans un seul client : pas d'account_id.
  def definitions
    TOOLS.values.map do |tool|
      schema = tool.input_schema_value.to_h.except(:"$schema")
      { name: tool.name_value, description: tool.description_value, input_schema: schema.merge(properties: schema[:properties].except(:account_id)) }
    end
  end

  def known?(name) = TOOLS.key?(name)

  # Un outil inconnu ou sans annotation compte comme une écriture.
  def writes?(name) = TOOLS[name]&.annotations_value&.read_only_hint != true

  # { "text" => …, "error" => true|false }
  def call(name, input)
    tool = TOOLS[name] or return { "text" => "Unknown tool #{name}", "error" => true }
    arguments = input.to_h.transform_keys(&:to_sym).except(:mark_read) # lire n'est pas « marquer comme lu »
    response = tool.call(server_context: @context, **arguments)
    { "text" => response.content.map { |block| block[:text] }.join("\n"), "error" => response.error? }
  rescue ArgumentError => error # argument manquant ou inconnu
    { "text" => error.message, "error" => true }
  end
end
