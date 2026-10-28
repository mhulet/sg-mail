class Mailbox < ApplicationRecord
  PROVIDERS = %w[gmail imap].freeze

  acts_as_tenant :account

  serialize :credentials, coder: JSON
  encrypts :credentials

  belongs_to :connected_by, class_name: "User", optional: true
  has_many :mail_folders, dependent: :destroy
  has_many :messages, dependent: :delete_all
  has_many :conversations, dependent: :delete_all
  has_many :accesses, class_name: "MailboxAccess", dependent: :delete_all
  has_many :users_with_access, through: :accesses, source: :user

  scope :accessible_by, ->(user) { where(id: MailboxAccess.where(user: user).select(:mailbox_id)) }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :address, presence: true, uniqueness: { scope: %i[account_id provider] }

  after_destroy_commit :revoke_google_access

  def access_for(user) = accesses.find_by(user: user)

  def grant!(user, level)
    accesses.find_or_initialize_by(user: user).update!(level: level)
  end

  def shared? = accesses.size > 1

  def gmail? = provider == "gmail"
  def imap? = provider == "imap"

  def revoke_google_access
    token = credentials&.dig("refresh_token")
    RevokeGoogleTokenJob.perform_later(token) if gmail? && token.present?
  end

  def synchronizer
    gmail? ? GmailSync.new(self) : ImapSync.new(self)
  end

  def sync!
    started_at = Time.current
    synchronizer.call
    # Marge d'un jour : un message importé pendant la synchro précédente n'échappe pas au Screener.
    Conversation.rebuild_for(self, since: last_synced_at&.-(1.day))
    GmailWatch.new(self).renew_if_needed if gmail?
    # La toute première synchro importe l'historique : on ne sonne pas pour des milliers de vieux messages.
    NotifyNewMailJob.perform_later(self, started_at) if last_synced_at
    update!(last_synced_at: Time.current, last_sync_error: nil)
  rescue => e
    update!(last_sync_error: "#{e.class}: #{e.message}")
    raise
  end
end
