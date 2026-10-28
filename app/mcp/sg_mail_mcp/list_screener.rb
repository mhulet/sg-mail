class SgMailMcp::ListScreener < SgMailMcp::Tool
  description <<~TEXT.squish
    The Screener: senders writing to me for the first time, waiting for my decision, with their latest thread,
    and the senders I blocked. Their threads stay out of my inbox (search still finds them) until I accept them.
    Decisions are mine only: colleagues screen for themselves.
  TEXT
  read_only!
  input_schema(properties: { limit: { type: "integer", minimum: 1, maximum: 200 } })

  def self.perform(actions, serializer, limit: 100)
    {
      pending: actions.screener(limit: limit).map { |conversation| serializer.screener_entry(conversation) },
      blocked: actions.blocked_senders.map { |screening| serializer.screening(screening) }
    }
  end
end
