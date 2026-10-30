class SgMailMcp::ListTasks < SgMailMcp::Tool
  description "Tasks, by due date. scope mine (assigned to me, or created by me and unassigned) or all (every task I can see)."
  read_only!
  locates conversation_id: Conversation
  aggregates!
  input_schema(properties: {
    scope: { type: "string", enum: %w[mine all] },
    status: { type: "string", enum: %w[open done all] },
    conversation_id: { type: "integer" }
  })

  def self.perform(actions, serializer, scope: "mine", status: "open", conversation_id: nil)
    { tasks: actions.tasks(scope: scope, status: status, conversation_id: conversation_id).map { |task| serializer.task(task) } }
  end
end
