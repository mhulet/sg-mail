class SgMailMcp::AddNote < SgMailMcp::Tool
  description "Add an internal note to a thread, signed by me: visible to colleagues only, never sent to the correspondent."
  writes!
  locates conversation_id: Conversation
  input_schema(properties: { conversation_id: { type: "integer" }, body: { type: "string" } }, required: %w[conversation_id body])

  def self.perform(actions, serializer, conversation_id:, body:)
    { note: serializer.note(actions.add_note(conversation_id, body)) }
  end
end
