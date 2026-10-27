class SgMailMcp::UpdateTask < SgMailMcp::Tool
  description "Complete (status done), reopen (status open) or edit a task."
  writes!(idempotent: true)
  input_schema(properties: {
    id: { type: "integer" },
    status: { type: "string", enum: %w[open done] },
    title: { type: "string" },
    assignee_id: { type: [ "integer", "null" ] },
    due_on: { type: [ "string", "null" ], description: "YYYY-MM-DD" },
    external_ref: { type: "string" }
  }, required: [ "id" ])

  def self.perform(actions, serializer, id:, status: nil, **attributes)
    { task: serializer.task(actions.update_task(id, status: status, **attributes)) }
  end
end
