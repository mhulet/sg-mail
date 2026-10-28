class SgMailMcp::ScreenSender < SgMailMcp::Tool
  description <<~TEXT.squish
    Accept a sender (their threads come into my inbox) or block them (their threads stay out of it), for me only.
    Nothing is deleted on the mail server. Ask the user before blocking someone.
  TEXT
  writes!(idempotent: true)
  input_schema(properties: {
    address: { type: "string", description: "Sender email address" },
    decision: { type: "string", enum: Screening::DECISIONS }
  }, required: %w[address decision])

  def self.perform(actions, serializer, address:, decision:)
    { screening: serializer.screening(actions.screen(address, decision)) }
  end
end
