class SgMailMcp::SearchConversations < SgMailMcp::Tool
  description <<~TEXT.squish
    List email threads, most recent first. Without query: the unified inbox (or one mailbox with mailbox_id),
    without the threads of senders still in my Screener or blocked by me.
    With query: full-text search in subject, sender, recipients and body; words match without accents and by prefix.
    Query filters: "de:anne" (sender), "a:formations" (recipient), "avec:pj" (with attachments).
  TEXT
  read_only!
  input_schema(properties: {
    query: { type: "string" },
    mailbox_id: { type: "integer" },
    unread: { type: "boolean", description: "Only threads with messages I have not read" },
    mine: { type: "boolean", description: "Only threads assigned to me" },
    before: { type: "string", description: "ISO 8601 time: threads whose last message is older (pagination)" },
    limit: { type: "integer", minimum: 1, maximum: 100 }
  })

  def self.perform(actions, serializer, query: nil, mailbox_id: nil, unread: false, mine: false, before: nil, limit: 30)
    conversations = actions.conversations(query: query, mailbox_id: mailbox_id, unread: unread, mine: mine, before: before, limit: limit)
    { conversations: conversations.map { |conversation| serializer.conversation(conversation) } }
  end
end
