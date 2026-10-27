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

  # Recalcule les fils d'une boîte après une synchro : un INSERT … ON CONFLICT et deux requêtes,
  # quel que soit le nombre de messages.
  def self.rebuild_for(mailbox)
    key = "COALESCE(messages.thread_key, 'uid:' || messages.provider_uid)"
    connection.execute(sanitize_sql_array([ <<~SQL, mailbox.id ]))
      INSERT INTO conversations (account_id, mailbox_id, thread_key, subject, last_sender, snippet,
        last_message_at, messages_count, in_inbox, created_at, updated_at)
      SELECT messages.account_id, messages.mailbox_id, #{key},
        (array_agg(messages.subject ORDER BY messages.sent_at NULLS LAST, messages.id))[1],
        (array_agg(COALESCE(NULLIF(messages.from_name, ''), messages.from_address) ORDER BY messages.sent_at DESC NULLS LAST, messages.id DESC))[1],
        (array_agg(messages.snippet ORDER BY messages.sent_at DESC NULLS LAST, messages.id DESC))[1],
        max(messages.sent_at), count(*),
        bool_or(messages.labels @> '["INBOX"]' OR COALESCE(mail_folders.name = 'INBOX', false)),
        now(), now()
      FROM messages LEFT JOIN mail_folders ON mail_folders.id = messages.mail_folder_id
      WHERE messages.mailbox_id = ?
      GROUP BY messages.account_id, messages.mailbox_id, #{key}
      ON CONFLICT (mailbox_id, thread_key) DO UPDATE SET
        subject = EXCLUDED.subject, last_sender = EXCLUDED.last_sender, snippet = EXCLUDED.snippet,
        last_message_at = EXCLUDED.last_message_at, messages_count = EXCLUDED.messages_count,
        in_inbox = EXCLUDED.in_inbox, updated_at = now()
      WHERE (conversations.last_message_at, conversations.messages_count, conversations.in_inbox)
        IS DISTINCT FROM (EXCLUDED.last_message_at, EXCLUDED.messages_count, EXCLUDED.in_inbox)
    SQL
    connection.execute(sanitize_sql_array([ <<~SQL, mailbox.id ]))
      UPDATE messages SET conversation_id = conversations.id
      FROM conversations
      WHERE messages.mailbox_id = ? AND conversations.mailbox_id = messages.mailbox_id
        AND conversations.thread_key = #{key}
        AND messages.conversation_id IS DISTINCT FROM conversations.id
    SQL
    where(mailbox: mailbox).where.not(id: Message.where(mailbox: mailbox).where.not(conversation_id: nil).select(:conversation_id)).delete_all
  end

  def title = subject.presence || "(sans objet)"

  def mark_read_by!(user) = Reading.mark!(user, messages)

  def mark_unread_by!(user)
    Reading.where(user: user, message_id: messages.reorder(sent_at: :desc, id: :desc).limit(1).select(:id)).delete_all
  end
end
