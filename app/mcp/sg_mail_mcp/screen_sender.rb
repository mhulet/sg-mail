class SgMailMcp::ScreenSender < SgMailMcp::Tool
  description <<~TEXT.squish
    Accept a sender into one of my boxes (imbox by default, feed for newsletters, paper_trail for receipts and
    notifications), or block them (their threads stay out), for me only. Accepting again with another box moves
    the sender there. Nothing is deleted on the mail server. Ask the user before blocking someone.
  TEXT
  writes!(idempotent: true)
  input_schema(properties: {
    address: { type: "string", description: "Sender email address" },
    decision: { type: "string", enum: Screening::DECISIONS },
    box: { type: "string", enum: Screening::BUCKETS, description: "For accepted; keeps the current box if omitted" }
  }, required: %w[address decision])

  def self.perform(actions, serializer, address:, decision:, box: nil)
    { screening: serializer.screening(actions.screen(address, decision, bucket: box)) }
  end
end
