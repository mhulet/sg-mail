# Un fil de discussion dans une boîte : les messages qui partagent la même clé de fil
# (threadId Gmail, ou premier Message-ID des References en IMAP).
class Conversation < ApplicationRecord
  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :assignee, class_name: "User", optional: true
  has_many :messages, -> { order(:sent_at, :id) }, dependent: :nullify
  has_many :notes, -> { order(:created_at) }, dependent: :delete_all
  has_many :tasks, dependent: :nullify

  scope :recent, -> { order(last_message_at: :desc, id: :desc) }
  scope :accessible_by, ->(user) { where(mailbox: Mailbox.accessible_by(user)) }
  scope :inbox, -> { where(in_inbox: true) }
  scope :assigned_to, ->(user) { where(assignee: user) }

  # Les fils d'une pile (imbox, feed, paper_trail) pour une personne : ceux des expéditeurs qu'elle y a
  # rangés. Un fil ouvert par la boîte elle-même va dans la réception.
  scope :in_bucket_for, ->(user, bucket = "imbox") {
    accepted = where(<<~SQL.squish, user.id, bucket)
      EXISTS (SELECT 1 FROM screenings WHERE screenings.user_id = ? AND screenings.address = conversations.sender_address
        AND screenings.decision = 'accepted' AND screenings.bucket = ?)
    SQL
    bucket == "imbox" ? where(sender_address: nil).or(accepted) : accepted
  }
  # Screener : un fil qui attend la décision de la personne.
  scope :screening_pending_for, ->(user) {
    where(<<~SQL.squish, user.id)
      conversations.sender_address IS NOT NULL AND NOT EXISTS (SELECT 1 FROM screenings WHERE screenings.user_id = ?
        AND screenings.address = conversations.sender_address)
    SQL
  }

  # Ajoute les colonnes « screening » (accepted, blocked, pending, ou nil pour un fil ouvert par la boîte)
  # et « bucket » (la pile d'un expéditeur accepté ; imbox pour un fil ouvert par la boîte).
  scope :with_screening_for, ->(user) {
    select("conversations.*", sanitize_sql_array([ <<~SQL.squish, user.id, user.id ]))
      CASE WHEN conversations.sender_address IS NULL THEN NULL ELSE COALESCE((SELECT screenings.decision FROM screenings
        WHERE screenings.user_id = ? AND screenings.address = conversations.sender_address), 'pending') END AS screening,
      CASE WHEN conversations.sender_address IS NULL THEN 'imbox' ELSE (SELECT screenings.bucket FROM screenings
        WHERE screenings.user_id = ? AND screenings.address = conversations.sender_address
        AND screenings.decision = 'accepted') END AS bucket
    SQL
  }

  # Ajoute la colonne « unread » : reste-t-il un message que cette personne n'a pas lu ?
  scope :with_unread_for, ->(user) {
    select(sanitize_sql_array([ <<~SQL.squish, user.id ]))
      conversations.*, EXISTS (
        SELECT 1 FROM messages WHERE messages.conversation_id = conversations.id
        AND NOT EXISTS (SELECT 1 FROM readings WHERE readings.message_id = messages.id AND readings.user_id = ?)
      ) AS unread
    SQL
  }

  scope :unread_for, ->(user) {
    where(<<~SQL.squish, user.id)
      EXISTS (SELECT 1 FROM messages WHERE messages.conversation_id = conversations.id
        AND NOT EXISTS (SELECT 1 FROM readings WHERE readings.message_id = messages.id AND readings.user_id = ?))
    SQL
  }

  # Le Screener d'une personne : un fil par expéditeur en attente (le plus récent), avec le nombre
  # de ses fils (colonne « sender_conversations_count »), les plus récents d'abord.
  def self.screener_for(user, limit: 200)
    latest = accessible_by(user).screening_pending_for(user)
      .select("DISTINCT ON (conversations.sender_address) conversations.*",
        "count(*) OVER (PARTITION BY conversations.sender_address) AS sender_conversations_count")
      .order("conversations.sender_address", last_message_at: :desc, id: :desc)
    from(latest, :conversations).includes(:mailbox).order(last_message_at: :desc, id: :desc).limit(limit)
  end

  # Recalcule les fils d'une boîte après une synchro : un INSERT … ON CONFLICT et deux requêtes,
  # quel que soit le nombre de messages. Puis le Screener accepte d'office les expéditeurs connus
  # (voir Screening.accept_known_senders!) ; `since` limite ce travail aux messages récents.
  def self.rebuild_for(mailbox, since: nil)
    key = "COALESCE(messages.thread_key, 'uid:' || messages.provider_uid)"
    inbound = sanitize_sql_array([ "messages.from_address IS NOT NULL AND lower(messages.from_address) <> ?", mailbox.address.downcase ])
    connection.execute(sanitize_sql_array([ <<~SQL, mailbox.id ]))
      INSERT INTO conversations (account_id, mailbox_id, thread_key, subject, last_sender, snippet,
        last_message_at, messages_count, in_inbox, sender_address, sender_name, created_at, updated_at)
      SELECT messages.account_id, messages.mailbox_id, #{key},
        (array_agg(messages.subject ORDER BY messages.sent_at NULLS LAST, messages.id))[1],
        (array_agg(COALESCE(NULLIF(messages.from_name, ''), messages.from_address) ORDER BY messages.sent_at DESC NULLS LAST, messages.id DESC))[1],
        (array_agg(messages.snippet ORDER BY messages.sent_at DESC NULLS LAST, messages.id DESC))[1],
        max(messages.sent_at), count(*),
        bool_or(messages.labels @> '["INBOX"]' OR COALESCE(mail_folders.name = 'INBOX', false)),
        (array_agg(lower(messages.from_address) ORDER BY messages.sent_at NULLS LAST, messages.id) FILTER (WHERE #{inbound}))[1],
        (array_agg(NULLIF(messages.from_name, '') ORDER BY messages.sent_at NULLS LAST, messages.id) FILTER (WHERE #{inbound}))[1],
        now(), now()
      FROM messages LEFT JOIN mail_folders ON mail_folders.id = messages.mail_folder_id
      WHERE messages.mailbox_id = ?
      GROUP BY messages.account_id, messages.mailbox_id, #{key}
      ON CONFLICT (mailbox_id, thread_key) DO UPDATE SET
        subject = EXCLUDED.subject, last_sender = EXCLUDED.last_sender, snippet = EXCLUDED.snippet,
        last_message_at = EXCLUDED.last_message_at, messages_count = EXCLUDED.messages_count,
        in_inbox = EXCLUDED.in_inbox, sender_address = EXCLUDED.sender_address, sender_name = EXCLUDED.sender_name,
        updated_at = now()
      WHERE (conversations.last_message_at, conversations.messages_count, conversations.in_inbox, conversations.sender_address)
        IS DISTINCT FROM (EXCLUDED.last_message_at, EXCLUDED.messages_count, EXCLUDED.in_inbox, EXCLUDED.sender_address)
    SQL
    connection.execute(sanitize_sql_array([ <<~SQL, mailbox.id ]))
      UPDATE messages SET conversation_id = conversations.id
      FROM conversations
      WHERE messages.mailbox_id = ? AND conversations.mailbox_id = messages.mailbox_id
        AND conversations.thread_key = #{key}
        AND messages.conversation_id IS DISTINCT FROM conversations.id
    SQL
    where(mailbox: mailbox).where.not(id: Message.where(mailbox: mailbox).where.not(conversation_id: nil).select(:conversation_id)).delete_all
    Screening.accept_known_senders!(mailbox, since: since)
  end

  def title = subject.presence || "(sans objet)"

  def sender_display = sender_name.presence || sender_address

  # accepted, blocked, pending, ou nil pour un fil ouvert par la boîte elle-même.
  def screening_for(user)
    return self[:screening] if has_attribute?(:screening)
    return unless sender_address

    screening_record_for(user)&.decision || "pending"
  end

  # imbox, feed ou paper_trail ; nil tant que l'expéditeur n'est pas accepté.
  def bucket_for(user)
    return self[:bucket] if has_attribute?(:bucket)
    return "imbox" unless sender_address

    screening = screening_record_for(user)
    screening.bucket if screening&.decision == "accepted"
  end

  def mark_read_by!(user) = Reading.mark!(user, messages)

  def mark_unread_by!(user)
    Reading.where(user: user, message_id: messages.reorder(sent_at: :desc, id: :desc).limit(1).select(:id)).delete_all
  end

  private

  def screening_record_for(user)
    @screening_records ||= {}
    @screening_records.fetch(user.id) { @screening_records[user.id] = Screening.find_by(user: user, address: sender_address) }
  end
end
