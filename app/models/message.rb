class Message < ApplicationRecord
  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :mail_folder, optional: true

  before_validation { self.account_id ||= mailbox&.account_id }

  scope :recent, -> { order(sent_at: :desc) }

  def unread_in_provider?
    labels.include?("UNREAD") || (mailbox.imap? && !labels.include?("Seen"))
  end
end
