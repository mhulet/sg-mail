# Ce que l'API, le CLI et le MCP peuvent faire, au nom d'une personne, dans le client courant.
# Mêmes règles que l'interface : on ne voit et ne touche que les boîtes auxquelles on a accès,
# et l'envoi d'un brouillon est toujours une action séparée.
class MailActions
  def initialize(user)
    @user = user
  end

  def mailboxes = Mailbox.accessible_by(@user).order(:address)
  def members = ActsAsTenant.current_tenant.users.order(:name)

  # Une pile (box : imbox par défaut, feed, paper_trail), une boîte, ou une recherche ; filtres non lus,
  # assignés à moi, avant une date. Hors recherche, seuls les fils d'expéditeurs acceptés (Screener)
  # et rangés dans cette pile apparaissent.
  def conversations(query: nil, box: nil, mailbox_id: nil, unread: false, mine: false, before: nil, limit: 50)
    raise ArgumentError, "box : imbox, feed ou paper_trail" unless box.blank? || box.in?(Screening::BUCKETS)
    mailbox = mailboxes.find(mailbox_id) if mailbox_id.present?
    scope = if query.present?
      MessageSearch.new(@user, query, mailbox: mailbox).conversations
    else
      scope = mailbox ? accessible_conversations.where(mailbox: mailbox) : accessible_conversations.inbox
      scope.in_bucket_for(@user, box.presence || "imbox")
    end
    scope = scope.with_unread_for(@user).with_screening_for(@user).includes(:mailbox, :assignee)
    scope = scope.unread_for(@user) if unread
    scope = scope.assigned_to(@user) if mine
    scope = scope.where(last_message_at: ...Time.zone.iso8601(before.to_s)) if before.present?
    scope.recent.limit(limit.to_i.clamp(1, 100))
  end

  def conversation(id, mark_read: false)
    conversation = accessible_conversations.find(id)
    conversation.mark_read_by!(@user) if mark_read
    conversation
  end

  def people(conversation) = conversation.mailbox.users_with_access.order(:name).to_a

  def mark_read(id) = conversation(id).tap { |c| c.mark_read_by!(@user) }
  def mark_unread(id) = conversation(id).tap { |c| c.mark_unread_by!(@user) }

  # assignee_id : une personne qui a accès à la boîte ; nil pour retirer l'assignation.
  def assign(id, assignee_id)
    conversation = conversation(id)
    assignee = people(conversation).find { |person| person.id == assignee_id.to_i } if assignee_id.present?
    raise ArgumentError, "assignee_id #{assignee_id} n'a pas accès à cette boîte" if assignee_id.present? && !assignee

    conversation.update!(assignee: assignee)
    conversation
  end

  # Screener : les expéditeurs qui attendent ma décision, avec leur fil le plus récent.
  def screener(limit: 100) = Conversation.screener_for(@user, limit: limit.to_i.clamp(1, 200))

  def blocked_senders = Screening.where(user: @user, decision: "blocked").order(updated_at: :desc)

  # decision : accepted (ses fils entrent dans la pile « bucket », imbox par défaut) ou blocked
  # (ils restent dehors), pour moi seulement. Accepter à nouveau avec une autre pile y déplace l'expéditeur.
  def screen(address, decision, bucket: nil) = Screening.decide!(@user, address, decision, bucket: bucket)

  def add_note(conversation_id, body)
    conversation(conversation_id).notes.create!(user: @user, body: body)
  end

  # Mes tâches (par défaut) ou toutes celles que je peux voir ; status open, done ou all.
  def tasks(scope: "mine", status: "open", conversation_id: nil, limit: 100)
    tasks = Task.visible_to(@user).includes(:assignee)
    tasks = tasks.for_user(@user) unless scope == "all"
    tasks = tasks.where(conversation_id: conversation_id) if conversation_id.present?
    tasks = tasks.where(status: status) unless status == "all"
    tasks.by_due_date.limit(limit.to_i.clamp(1, 500))
  end

  def task(id) = Task.visible_to(@user).find(id)

  # Depuis un message ou un fil, ou libre. Confiée à soi-même si assignee_id n'est pas donné.
  def create_task(title:, message_id: nil, conversation_id: nil, assignee_id: :me, due_on: nil, external_ref: nil)
    task = Task.new(title: title, creator: @user, due_on: due_on, external_ref: external_ref,
      assignee_id: assignee_id == :me ? @user.id : assignee_id.presence)
    task.message = accessible_messages.find(message_id) if message_id.present?
    task.conversation = accessible_conversations.find(conversation_id) if conversation_id.present?
    task.save!
    task
  end

  def update_task(id, status: nil, **attributes)
    task = task(id)
    case status
    when "done" then task.complete!
    when "open" then task.reopen!
    when nil then nil
    else raise ArgumentError, "status : open ou done"
    end
    task.update!(attributes.slice(:title, :due_on, :assignee_id, :external_ref)) if attributes.any?
    task
  end

  def drafts(limit: 50) = Draft.where(user: @user).editable.includes(:mailbox).order(updated_at: :desc).limit(limit.to_i.clamp(1, 100))
  def draft(id) = Draft.where(user: @user).editable.find(id)

  # Réponse ou transfert d'un message : destinataires, objet et citation sont préparés et « body »
  # se place au-dessus de la citation. Sans message, un nouveau message.
  def create_draft(message_id: nil, kind: nil, mailbox_id: nil, body: nil, **fields)
    mailbox = sendable_mailboxes.find(mailbox_id) if mailbox_id.present?
    if message_id.present?
      message = accessible_messages.find(message_id)
      kind = kind.presence_in(Draft::KINDS - [ "new" ]) || "reply"
      draft = Draft.build_from(message, kind: kind, user: @user, mailbox: mailbox || default_mailbox_for(message))
      draft.body = "#{body}#{draft.body}" if body.present?
    else
      draft = Draft.new(kind: "new", user: @user, mailbox: mailbox || sendable_mailboxes.first, body: body)
    end
    draft.assign_attributes(draft_fields(fields))
    draft.save!
    draft
  end

  def update_draft(id, body: nil, **fields)
    draft = draft(id)
    draft.body = body unless body.nil?
    draft.assign_attributes(draft_fields(fields))
    draft.save!
    draft
  end

  def deliver_draft(id)
    draft = draft(id)
    draft.update!(status: "sending")
    SendDraftJob.perform_later(draft)
    draft
  end

  private

  def accessible_conversations = Conversation.accessible_by(@user)
  def accessible_messages = Message.where(mailbox: Mailbox.accessible_by(@user))

  def sendable_mailboxes = Mailbox.where(id: MailboxAccess.where(user: @user, level: %w[send manage]).select(:mailbox_id)).order(:address)

  def default_mailbox_for(message) = sendable_mailboxes.find_by(id: message.mailbox_id) || sendable_mailboxes.first || message.mailbox

  def draft_fields(fields)
    fields.slice(:subject, :to, :cc, :bcc).compact.to_h do |key, value|
      key == :subject ? [ :subject, value ] : [ :"#{key}_addresses", Array(value) ]
    end
  end
end
