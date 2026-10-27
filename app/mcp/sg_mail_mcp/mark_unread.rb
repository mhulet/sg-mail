class SgMailMcp::MarkUnread < SgMailMcp::Tool
  description "Mark a thread as unread for me only."
  writes!(idempotent: true)
  input_schema(properties: { conversation_id: { type: "integer" } }, required: [ "conversation_id" ])

  def self.perform(actions, serializer, conversation_id:)
    { conversation: serializer.conversation(actions.mark_unread(conversation_id)) }
  end
end
