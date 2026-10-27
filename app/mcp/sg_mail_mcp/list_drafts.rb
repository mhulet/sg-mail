class SgMailMcp::ListDrafts < SgMailMcp::Tool
  description "My unsent drafts (and failed sends, with the error)."
  read_only!
  input_schema(properties: {})

  def self.perform(actions, serializer)
    { drafts: actions.drafts.map { |draft| serializer.draft(draft) } }
  end
end
