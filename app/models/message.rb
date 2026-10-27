class Message < ApplicationRecord
  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :mail_folder, optional: true
  belongs_to :conversation, optional: true
  has_many :readings, dependent: :delete_all

  before_validation { self.account_id ||= mailbox&.account_id }

  scope :recent, -> { order(sent_at: :desc) }

  def from_display = from_name.presence || from_address

  def read_by?(user) = readings.any? { |reading| reading.user_id == user.id }

  def unread_in_provider?
    labels.include?("UNREAD") || (mailbox.imap? && !labels.include?("Seen"))
  end
end
