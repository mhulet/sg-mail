# Note interne sur un fil : visible de l'équipe qui a accès à la boîte, jamais du correspondant.
class Note < ApplicationRecord
  acts_as_tenant :account
  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true
end
