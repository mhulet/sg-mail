class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :name, presence: true

  def display_name = name.presence || email_address
end
