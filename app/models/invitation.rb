# Invitation à rejoindre un client, envoyée par email et valable VALIDITY.
class Invitation < ApplicationRecord
  VALIDITY = 14.days

  belongs_to :account
  belongs_to :invited_by, class_name: "User"

  has_secure_token :token, length: 32
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: Membership::ROLES }
  validate :not_already_member, on: :create

  scope :pending, -> { where(accepted_at: nil).where(created_at: VALIDITY.ago..) }

  def self.find_pending_by_token(token)
    pending.find_by(token: token.to_s)
  end

  def expires_at = created_at + VALIDITY

  # Ajoute l'utilisateur au client ; une invitation ne sert qu'une fois.
  def accept!(user)
    transaction do
      lock!
      raise ActiveRecord::RecordNotFound, "Invitation déjà utilisée" if accepted_at
      account.memberships.find_or_create_by!(user: user) { |membership| membership.role = role }
      update!(accepted_at: Time.current)
    end
  end

  private

  def not_already_member
    if account&.users&.exists?(email_address: email_address)
      errors.add(:email_address, "fait déjà partie de ce client")
    end
  end
end
