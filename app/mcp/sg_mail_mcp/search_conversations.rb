class SgMailMcp::SearchConversations < SgMailMcp::Tool
  description <<~TEXT.squish
    List email threads, most recent first. Without query: one of my boxes, like Hey: "imbox" (default, the inbox),
    "feed" (newsletters, reading) or "paper_trail" (receipts, notifications), across mailboxes or in one with mailbox_id.
    Threads of senders still in my Screener or blocked by me are left out, and so are threads in my stacks:
    list those with stack "reply_later" or "set_aside". Threads I archived are left out too: list them with archived.
    With query: Gmail-style search. Words match subject, sender, recipients, body and attachment names, without
    accents and by prefix, and also the thread's internal notes and tasks; "exact phrase"; -word excludes.
    Operators: from:, to:, cc:, subject:, filename:, has:attachment, has:note, has:task, before:YYYY/MM/DD,
    after:YYYY/MM/DD, older_than:/newer_than: (7d, 2w, 3m, 1y), is:unread, is:read, is:assigned, is:unassigned,
    assignee:me or a name, in:inbox|feed|paper_trail|screener|reply_later|set_aside|archive|sent or a mailbox
    address prefix, mailbox:; prefix any operator with - to exclude, quote values with spaces (subject:"bon de commande").
  TEXT
  read_only!
  input_schema(properties: {
    query: { type: "string" },
    box: { type: "string", enum: Screening::BUCKETS, description: "Without query; default imbox" },
    stack: { type: "string", enum: ConversationState::STACKS, description: "Without query: my reply later or set aside stack" },
    mailbox_id: { type: "integer" },
    unread: { type: "boolean", description: "Only threads with messages I have not read" },
    mine: { type: "boolean", description: "Only threads assigned to me" },
    archived: { type: "boolean", description: "Without query: the threads I archived" },
    before: { type: "string", description: "ISO 8601 time: threads whose last message is older (pagination)" },
    limit: { type: "integer", minimum: 1, maximum: 100 }
  })

  def self.perform(actions, serializer, query: nil, box: nil, stack: nil, mailbox_id: nil, unread: false, mine: false, before: nil, limit: 30, archived: false)
    conversations = actions.conversations(query: query, box: box, stack: stack, mailbox_id: mailbox_id, unread: unread, mine: mine, before: before, limit: limit,
      archived: archived)
    { conversations: conversations.map { |conversation| serializer.conversation(conversation) } }
  end
end
