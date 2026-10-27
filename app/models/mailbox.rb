class Mailbox < ApplicationRecord
  PROVIDERS = %w[gmail imap].freeze

  serialize :credentials, coder: JSON
  encrypts :credentials

  has_many :mail_folders, dependent: :destroy
  has_many :messages, dependent: :delete_all

  validates :provider, inclusion: { in: PROVIDERS }
  validates :address, presence: true, uniqueness: { scope: :provider }

  def gmail? = provider == "gmail"
  def imap? = provider == "imap"

  def synchronizer
    gmail? ? GmailSync.new(self) : ImapSync.new(self)
  end

  def sync!
    synchronizer.call
    update!(last_synced_at: Time.current, last_sync_error: nil)
  rescue => e
    update!(last_sync_error: "#{e.class}: #{e.message}")
    raise
  end
end
