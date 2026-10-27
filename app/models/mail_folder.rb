class MailFolder < ApplicationRecord
  acts_as_tenant :account
  belongs_to :mailbox
  has_many :messages, dependent: :delete_all

  before_validation { self.account_id ||= mailbox&.account_id }
end
