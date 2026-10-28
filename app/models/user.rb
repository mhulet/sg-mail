class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :passkeys, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :name, presence: true

  def display_name = name.presence || email_address

  # Identifiant WebAuthn de la personne : aléatoire, sans rien révéler d'elle.
  def webauthn_id!
    webauthn_id || tap { update!(webauthn_id: WebAuthn.generate_user_id) }.webauthn_id
  end
end
