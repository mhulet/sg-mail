class SgMailMcp::CreateTask < SgMailMcp::Tool
  description <<~TEXT.squish
    Create a task, usually from an email (message_id) or a thread (conversation_id). Assigned to me unless assignee_id
    is given (null: nobody). external_ref keeps a link to the same task in another tool (e.g. a MySemisto URL).
  TEXT
  writes!
  locates message_id: Message, conversation_id: Conversation
  input_schema(properties: {
    title: { type: "string" },
    message_id: { type: "integer" },
    conversation_id: { type: "integer" },
    assignee_id: { type: [ "integer", "null" ] },
    due_on: { type: "string", description: "YYYY-MM-DD" },
    external_ref: { type: "string" }
  }, required: [ "title" ])

  def self.perform(actions, serializer, title:, assignee_id: :me, **options)
    { task: serializer.task(actions.create_task(title: title, assignee_id: assignee_id, **options)) }
  end
end
