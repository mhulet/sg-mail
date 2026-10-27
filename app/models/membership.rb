class Membership < ApplicationRecord
  ROLES = %w[admin member].freeze

  belongs_to :account
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :keeps_an_admin, on: :update

  before_destroy :ensure_not_last_admin

  scope :admins, -> { where(role: "admin") }

  def admin? = role == "admin"

  def role_label = Membership.role_label(role)

  def self.role_label(role) = role == "admin" ? "Admin" : "Membre"

  private

  def last_admin?
    role_was == "admin" && account.memberships.admins.where.not(id: id).none?
  end

  def keeps_an_admin
    errors.add(:role, "ne peut pas changer : il faut au moins un admin") if role_changed? && last_admin?
  end

  def ensure_not_last_admin
    return unless last_admin?

    errors.add(:base, "Impossible de retirer le dernier admin du client.")
    throw :abort
  end
end
