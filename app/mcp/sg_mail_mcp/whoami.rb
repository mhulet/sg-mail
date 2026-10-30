class SgMailMcp::Whoami < SgMailMcp::Tool
  description "Who is signed in, in which organisation (account), with which mailboxes (and access level) and which colleagues. " \
    "When I belong to several organisations: each of them (accounts), with its mailboxes and colleagues."
  read_only!
  aggregates!
  input_schema(properties: {})

  def self.perform(actions, serializer)
    { user: serializer.user(Current.user), account: serializer.account(Current.account),
      mailboxes: actions.mailboxes.map { |mailbox| serializer.mailbox(mailbox) },
      members: actions.members.map { |user| serializer.user(user) } }
  end

  def self.combine(results, **)
    { user: results.first.last[:user], accounts: results.map { |account, result| account.merge(result.slice(:mailboxes, :members)) } }
  end
end
