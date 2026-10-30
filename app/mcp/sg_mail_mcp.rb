# Serveur MCP de SG Mail (/mcp) : Claude lit les fils, rédige des brouillons, crée des tâches et des notes
# au nom de la personne connectée, dans son client ou dans tous ses clients (SgMailMcp::Accounts).
# Tout passe par MailActions, comme l'API.
module SgMailMcp
  VERSION = "1.0.0"

  INSTRUCTIONS = <<~TEXT
    SG Mail is a shared email client: several people of the same organisation read personal and shared
    mailboxes (Gmail or IMAP). Read status is per person ("read by…"), threads can be assigned to someone,
    and emails become tasks and internal notes that the correspondent never sees.
    Like Hey, a Screener keeps first-time senders out of each person's inbox until that person accepts them
    (list_screener, screen_sender), and each accepted sender lands in one of that person's boxes: imbox,
    feed (newsletters) or paper_trail (receipts, notifications). Each person can also keep a thread to
    "reply later" or "set aside", or archive it when done (update_stacks). Search still finds every thread.
    Start with whoami (mailboxes and colleagues), then search_conversations and get_conversation.
    To answer an email, create a draft with create_draft and show it to the user. Only call send_draft after
    the user explicitly asked to send that draft: it sends a real email. Dates are ISO 8601. Write emails
    in the language of the thread (usually French).
    When I belong to several organisations (accounts), the tools cover all of them: lists gather every
    organisation and each item says which one it comes from (account); ids are unique across organisations.
    Pass account_id to look at one organisation only, or when creating something not tied to a thread or mailbox.
  TEXT

  TOOLS = [
    Whoami, SearchConversations, GetConversation, MarkRead, MarkUnread, Assign, AddNote, ListScreener, ScreenSender, UpdateStacks,
    ListTasks, CreateTask, UpdateTask, ListDrafts, CreateDraft, UpdateDraft, SendDraft
  ].freeze

  # memberships : les clients que couvre le connecteur, quand il y en a plusieurs.
  def self.server(user:, base_url: nil, memberships: [])
    accounts = SgMailMcp::Accounts.new(memberships) if memberships.many?
    MCP::Server.new(
      name: "sg-mail", title: "SG Mail", version: VERSION, instructions: INSTRUCTIONS, tools: TOOLS,
      server_context: { actions: MailActions.new(user), serializer: ApiSerializer.new(user: user, base_url: base_url), accounts: accounts }
    )
  end
end
