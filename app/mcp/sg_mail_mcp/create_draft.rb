class SgMailMcp::CreateDraft < SgMailMcp::Tool
  description <<~TEXT.squish
    Prepare an email without sending it. With message_id: a reply (kind reply or reply_all) or a forward (kind forward);
    recipients, subject and quotation are filled in and body goes above the quotation. Without message_id: a new email
    (give to and subject). Sent from the mailbox of the original message when I may send from it, or from mailbox_id.
    Show the draft to the user; it can also be edited and sent from SG Mail (url).
  TEXT
  writes!
  input_schema(properties: {
    message_id: { type: "integer" },
    kind: { type: "string", enum: %w[reply reply_all forward] },
    mailbox_id: { type: "integer" },
    to: { type: "array", items: { type: "string" } },
    cc: { type: "array", items: { type: "string" } },
    bcc: { type: "array", items: { type: "string" } },
    subject: { type: "string" },
    body: { type: "string", description: "Plain text" }
  })

  def self.perform(actions, serializer, **arguments)
    { draft: serializer.draft(actions.create_draft(**arguments)) }
  end
end
