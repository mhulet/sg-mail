class SgMailMcp::MarkRead < SgMailMcp::Tool
  description "Mark a thread as read for me only (colleagues keep their own read status; the mail server is not touched)."
  writes!(idempotent: true)
  locates conversation_id: Conversation
  input_schema(properties: { conversation_id: { type: "integer" } }, required: [ "conversation_id" ])

  def self.perform(actions, serializer, conversation_id:)
    { conversation: serializer.conversation(actions.mark_read(conversation_id)) }
  end
end
