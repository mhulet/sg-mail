# Une tâche, souvent née d'un email. Visible de ceux qui ont accès au fil, ou, sans fil,
# de sa créatrice et de la personne à qui elle est confiée.
class Task < ApplicationRecord
  STATUSES = %w[open done].freeze

  acts_as_tenant :account
  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :assignee_is_member

  before_validation { self.conversation ||= message&.conversation }

  scope :open, -> { where(status: "open") }
  scope :done, -> { where(status: "done") }
  scope :by_due_date, -> { order(Arel.sql("due_on IS NULL, due_on, created_at")) }
  scope :visible_to, ->(user) {
    where(conversation: Conversation.accessible_by(user))
      .or(where(conversation_id: nil, creator: user))
      .or(where(conversation_id: nil, assignee: user))
  }
  # « Mes tâches » : celles qu'on m'a confiées, et celles que j'ai créées sans les confier.
  scope :for_user, ->(user) { where(assignee: user).or(where(assignee_id: nil, creator: user)) }

  def done? = status == "done"
  def overdue? = !done? && due_on && due_on < Date.current

  def complete! = update!(status: "done", completed_at: Time.current)
  def reopen! = update!(status: "open", completed_at: nil)

  private

  def assignee_is_member
    return unless assignee && account

    errors.add(:assignee, "ne fait pas partie du client") unless account.memberships.exists?(user: assignee)
  end
end
