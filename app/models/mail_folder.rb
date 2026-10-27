class MailFolder < ApplicationRecord
  belongs_to :mailbox
  has_many :messages, dependent: :delete_all
end
