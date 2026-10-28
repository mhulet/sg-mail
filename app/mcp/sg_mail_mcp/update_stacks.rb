class SgMailMcp::UpdateStacks < SgMailMcp::Tool
  description <<~TEXT.squish
    Put a thread in my "reply later" or "set aside" stack (true), or take it out (false), for me only.
    A thread in one of these stacks leaves my imbox, feed or paper trail until taken out; sending a reply to it
    takes it out of "reply later". List a stack with search_conversations and stack.
    archived true archives the thread for me (done with it: it leaves my boxes and "reply later" until a new message
    arrives; once everyone with access archived it, it also leaves the Gmail inbox); false brings it back.
  TEXT
  writes!(idempotent: true)
  input_schema(properties: {
    conversation_id: { type: "integer" },
    reply_later: { type: "boolean" },
    set_aside: { type: "boolean" },
    archived: { type: "boolean" }
  }, required: [ "conversation_id" ])

  def self.perform(actions, serializer, conversation_id:, reply_later: nil, set_aside: nil, archived: nil)
    { conversation: serializer.conversation(actions.update_stacks(conversation_id, reply_later: reply_later, set_aside: set_aside, archived: archived)) }
  end
end
