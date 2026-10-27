class SgMailMcp::SendDraft < SgMailMcp::Tool
  description <<~TEXT.squish
    Send one of my drafts: a real email leaves the mailbox. Only call this after the user explicitly asked to send
    this draft, having seen its final text. Sending happens in the background; list_drafts shows a failed send.
  TEXT
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false, open_world_hint: true)
  input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])

  def self.perform(actions, serializer, id:)
    { draft: serializer.draft(actions.deliver_draft(id)) }
  end
end
