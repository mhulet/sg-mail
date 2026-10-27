class SgMailMcp::Assign < SgMailMcp::Tool
  description "Assign a thread to someone who has access to its mailbox (ids from whoami), or unassign it with assignee_id null."
  writes!(idempotent: true)
  input_schema(properties: {
    conversation_id: { type: "integer" },
    assignee_id: { type: [ "integer", "null" ] }
  }, required: [ "conversation_id" ])

  def self.perform(actions, serializer, conversation_id:, assignee_id: nil)
    { conversation: serializer.conversation(actions.assign(conversation_id, assignee_id)) }
  end
end
