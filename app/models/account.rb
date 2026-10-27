# Un client de Super Génial (Semisto, Silvéa…). Tout ce qui touche aux emails lui appartient.
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy

  validates :name, presence: true

  # Les boîtes et leurs messages sont protégés par la Row Level Security : on les efface sous ce client.
  before_destroy { Tenancy.with_account(self) { Mailbox.destroy_all } }
end
