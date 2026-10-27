class SgMailMcp::UpdateDraft < SgMailMcp::Tool
  description "Edit one of my drafts. body replaces the whole text, quotation included."
  writes!(idempotent: true)
  input_schema(properties: {
    id: { type: "integer" },
    to: { type: "array", items: { type: "string" } },
    cc: { type: "array", items: { type: "string" } },
    bcc: { type: "array", items: { type: "string" } },
    subject: { type: "string" },
    body: { type: "string" }
  }, required: [ "id" ])

  def self.perform(actions, serializer, id:, **fields)
    { draft: serializer.draft(actions.update_draft(id, **fields)) }
  end
end
