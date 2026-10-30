# Représentation JSON commune à l'API, au CLI et au MCP. Jamais de secret (jetons, mots de passe).
class ApiSerializer
  def initialize(user:, base_url: nil)
    @user = user
    @base_url = base_url
  end

  def user(user) = user && { id: user.id, name: user.display_name, email: user.email_address }

  def account(account) = { id: account.id, name: account.name }

  def mailbox(mailbox)
    { id: mailbox.id, address: mailbox.address, label: mailbox.label, provider: mailbox.provider, shared: mailbox.shared?,
      access: mailbox.access_for(@user)&.level }
  end

  def conversation(conversation)
    {
      id: conversation.id, subject: conversation.title, mailbox_id: conversation.mailbox_id,
      mailbox: conversation.mailbox.address, last_sender: conversation.last_sender, snippet: conversation.snippet,
      # Le même email reçu dans d'autres boîtes : leurs fils.
      also_in: conversation.twins_for(@user).map { |twin| { id: twin.id, mailbox: twin.mailbox.address } },
      sender: conversation.sender_address && { address: conversation.sender_address, name: conversation.sender_name },
      screening: conversation.screening_for(@user), box: conversation.bucket_for(@user),
      stacks: conversation.stacks_for(@user), archived: conversation.archived_for?(@user),
      messages_count: conversation.messages_count, last_message_at: conversation.last_message_at&.iso8601,
      unread: conversation.has_attribute?(:unread) ? conversation.unread : nil,
      assignee: user(conversation.assignee), url: url("/#{conversation.account_id}/conversations/#{conversation.id}")
    }
  end

  # Le fil complet : messages avec leur texte, qui les a lus, et notes internes.
  def conversation_detail(conversation, people:)
    conversation(conversation).merge(
      messages: conversation.messages.includes(:readings).map { |message| message(message, people: people) },
      notes: conversation.notes.includes(:user).map { |note| note(note) }
    )
  end

  def message(message, people: [])
    {
      id: message.id, conversation_id: message.conversation_id, sent_at: message.sent_at&.iso8601,
      from: { name: message.from_name, address: message.from_address },
      to: message.to_addresses, cc: message.cc_addresses, subject: message.subject,
      body: message.body_text.presence || ActionView::Base.full_sanitizer.sanitize(message.body_html.to_s).squeeze("\n"),
      attachments: message.attachments.map { |a| a.slice("index", "filename", "content_type", "size") },
      read_by: people.select { |person| message.read_by?(person) }.map(&:display_name)
    }
  end

  # Un expéditeur du Screener, avec son fil le plus récent.
  def screener_entry(conversation)
    { address: conversation.sender_address, name: conversation.sender_name,
      conversations_count: conversation.sender_conversations_count, latest_conversation: conversation(conversation) }
  end

  def screening(screening)
    { address: screening.address, decision: screening.decision, box: (screening.bucket if screening.decision == "accepted"),
      decided_at: screening.updated_at.iso8601 }
  end

  def note(note) = { id: note.id, author: note.user.display_name, body: note.body, created_at: note.created_at.iso8601 }

  def draft(draft)
    {
      id: draft.id, status: draft.status, kind: draft.kind, mailbox: draft.mailbox.address,
      conversation_id: draft.conversation_id, source_message_id: draft.source_message_id,
      to: draft.to_addresses, cc: draft.cc_addresses, bcc: draft.bcc_addresses,
      subject: draft.subject, body: draft.body, error: draft.error, url: url("/#{draft.account_id}/drafts/#{draft.id}/edit")
    }
  end

  private

  def url(path) = @base_url ? "#{@base_url}#{path}" : path
end
