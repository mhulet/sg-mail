class Mailbox < ApplicationRecord
  PROVIDERS = %w[gmail imap].freeze

  acts_as_tenant :account

  serialize :credentials, coder: JSON
  encrypts :credentials

  belongs_to :connected_by, class_name: "User", optional: true
  has_many :mail_folders, dependent: :destroy
  has_many :messages, dependent: :delete_all
  has_many :accesses, class_name: "MailboxAccess", dependent: :delete_all
  has_many :users_with_access, through: :accesses, source: :user

  scope :accessible_by, ->(user) { where(id: MailboxAccess.where(user: user).select(:mailbox_id)) }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :address, presence: true, uniqueness: { scope: %i[account_id provider] }

  def access_for(user) = accesses.find_by(user: user)

  def grant!(user, level)
    accesses.find_or_initialize_by(user: user).update!(level: level)
  end

  def shared? = accesses.size > 1

  def gmail? = provider == "gmail"
  def imap? = provider == "imap"

  def synchronizer
    gmail? ? GmailSync.new(self) : ImapSync.new(self)
  end

  def sync!
    synchronizer.call
    GmailWatch.new(self).renew_if_needed if gmail?
    update!(last_synced_at: Time.current, last_sync_error: nil)
  rescue => e
    update!(last_sync_error: "#{e.class}: #{e.message}")
    raise
  end
end
