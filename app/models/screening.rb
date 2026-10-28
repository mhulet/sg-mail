# Screener, façon Hey : la décision d'une personne sur un expéditeur, pour elle seule.
# Sans décision, les fils de cet expéditeur attendent dans « À trier » ; bloqué, ils restent dehors
# (rien n'est supprimé chez Gmail ou sur le serveur IMAP, et la recherche les trouve toujours).
#
# Un expéditeur accepté est rangé dans une pile : la réception (Imbox), le Feed (lettres d'info, lectures)
# ou le Paper Trail (reçus, confirmations, notifications).
class Screening < ApplicationRecord
  DECISIONS = %w[accepted blocked].freeze
  BUCKETS = %w[imbox feed paper_trail].freeze
  BUCKET_LABELS = { "imbox" => "Réception", "feed" => "Feed", "paper_trail" => "Paper Trail" }.freeze

  acts_as_tenant :account
  belongs_to :user

  normalizes :address, with: ->(address) { address.strip.downcase }

  validates :decision, inclusion: { in: DECISIONS }
  validates :bucket, inclusion: { in: BUCKETS }
  validates :address, presence: true

  # Sans pile précisée, un expéditeur accepté garde la sienne (la réception pour un nouveau).
  def self.decide!(user, address, decision, bucket: nil)
    raise ArgumentError, "decision : accepted ou blocked" unless decision.in?(DECISIONS)
    raise ArgumentError, "bucket : imbox, feed ou paper_trail" unless bucket.blank? || bucket.in?(BUCKETS)

    screening = find_or_initialize_by(user: user, address: normalize_value_for(:address, address.to_s))
    screening.update!(decision: decision, bucket: bucket.presence || screening.bucket)
    screening
  end

  def bucket_label = BUCKET_LABELS.fetch(bucket)

  # Accepte d'office, pour chaque personne qui a accès à la boîte, ce qui n'a rien de nouveau :
  # les expéditeurs déjà là quand elle a reçu l'accès, et les personnes à qui la boîte a écrit.
  # `since` limite le travail aux messages importés depuis la dernière synchro.
  def self.accept_known_senders!(mailbox, since: nil, user: nil)
    accesses = "mailbox_accesses.mailbox_id = messages.mailbox_id"
    accesses += " AND mailbox_accesses.user_id = #{Integer(user.id)}" if user
    recent = since ? sanitize_sql_array([ "AND messages.created_at >= ?", since ]) : ""
    own_address = connection.quote(mailbox.address.downcase)

    connection.execute(sanitize_sql_array([ <<~SQL, mailbox.id, mailbox.id ]))
      INSERT INTO screenings (account_id, user_id, address, decision, created_at, updated_at)
      SELECT DISTINCT messages.account_id, mailbox_accesses.user_id, lower(messages.from_address), 'accepted', now(), now()
      FROM messages JOIN mailbox_accesses ON #{accesses}
      WHERE messages.mailbox_id = ? #{recent} AND messages.from_address IS NOT NULL
        AND lower(messages.from_address) <> #{own_address} AND messages.sent_at < mailbox_accesses.created_at
      UNION
      SELECT DISTINCT messages.account_id, mailbox_accesses.user_id, lower(recipient.address), 'accepted', now(), now()
      FROM messages JOIN mailbox_accesses ON #{accesses}
      CROSS JOIN LATERAL jsonb_array_elements_text(messages.to_addresses || messages.cc_addresses) AS recipient(address)
      WHERE messages.mailbox_id = ? #{recent} AND lower(messages.from_address) = #{own_address}
      ON CONFLICT DO NOTHING
    SQL
  end
end
