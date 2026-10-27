# Accès d'une personne à une boîte : lecture, envoi, ou gestion (droits des autres, déconnexion).
class MailboxAccess < ApplicationRecord
  LEVELS = %w[read send manage].freeze
  LABELS = { "read" => "Lecture", "send" => "Lecture et envoi", "manage" => "Gestion" }.freeze

  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :user

  before_validation { self.account_id ||= mailbox&.account_id }

  validates :level, inclusion: { in: LEVELS }
  validates :user_id, uniqueness: { scope: :mailbox_id }
  validate :user_is_member

  def can_send? = level.in?(%w[send manage])
  def can_manage? = level == "manage"
  def label = LABELS.fetch(level)

  private

  def user_is_member
    errors.add(:user, "ne fait pas partie du client") unless account&.memberships&.exists?(user_id: user_id)
  end
end
