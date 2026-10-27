class SgMailMcp::Whoami < SgMailMcp::Tool
  description "Who is signed in, in which organisation, with which mailboxes (and access level) and which colleagues."
  read_only!
  input_schema(properties: {})

  def self.perform(actions, serializer)
    { user: serializer.user(Current.user), account: serializer.account(Current.account),
      mailboxes: actions.mailboxes.map { |mailbox| serializer.mailbox(mailbox) },
      members: actions.members.map { |user| serializer.user(user) } }
  end
end
