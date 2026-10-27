class Message < ApplicationRecord
  belongs_to :mailbox
  belongs_to :mail_folder, optional: true

  scope :recent, -> { order(sent_at: :desc) }

  def unread_in_provider?
    labels.include?("UNREAD") || (mailbox.imap? && !labels.include?("Seen"))
  end
end
