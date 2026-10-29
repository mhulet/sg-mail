# Accès d'une personne à une boîte : lecture, envoi, ou gestion (droits des autres, déconnexion).
class MailboxAccess < ApplicationRecord
  LEVELS = %w[read send manage].freeze
  LABELS = { "read" => "Lecture", "send" => "Lecture et envoi", "manage" => "Gestion" }.freeze
  SHORT_LABELS = { "read" => "Lecture", "send" => "Envoi", "manage" => "Gestion" }.freeze

  acts_as_tenant :account
  belongs_to :mailbox
  belongs_to :user

  before_validation { self.account_id ||= mailbox&.account_id }

  validates :level, inclusion: { in: LEVELS }
  validates :user_id, uniqueness: { scope: :mailbox_id }
  validate :user_is_member

  # Le Screener ne présente pas l'historique de la boîte à qui vient d'y avoir accès.
  after_create { Screening.accept_known_senders!(mailbox, user: user) }

  def can_send? = level.in?(%w[send manage])
  def can_manage? = level == "manage"
  def label = LABELS.fetch(level)

  def self.change_notice(user, mailbox, level)
    level ? "#{user.display_name} : #{LABELS.fetch(level).downcase} sur #{mailbox.address}." : "#{user.display_name} n'a plus accès à #{mailbox.address}."
  end

  private

  def user_is_member
    errors.add(:user, "ne fait pas partie du client") unless account&.memberships&.exists?(user_id: user_id)
  end
end
