class SgMailMcp::GetConversation < SgMailMcp::Tool
  description "A full thread: every message with its text and attachments, who read it, internal notes and tasks."
  read_only!
  input_schema(properties: {
    id: { type: "integer" },
    mark_read: { type: "boolean", description: "Also mark the thread as read for me (default false)" }
  }, required: [ "id" ])

  def self.perform(actions, serializer, id:, mark_read: false)
    conversation = actions.conversation(id, mark_read: mark_read)
    { conversation: serializer.conversation_detail(conversation, people: actions.people(conversation)) }
  end
end
