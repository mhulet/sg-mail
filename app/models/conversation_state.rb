# Les piles personnelles d'un fil, façon Hey : « Répondre plus tard » et « Mis de côté ».
# Une ligne par personne et par fil ; l'horodatage dit depuis quand le fil est dans la pile.
class ConversationState < ApplicationRecord
  STACKS = %w[reply_later set_aside].freeze
  COLUMNS = { "reply_later" => :reply_later_at, "set_aside" => :set_aside_at }.freeze
  STACK_LABELS = { "reply_later" => "Répondre plus tard", "set_aside" => "Mis de côté" }.freeze
  ACTION_LABELS = { "reply_later" => "Répondre plus tard", "set_aside" => "Mettre de côté" }.freeze

  acts_as_tenant :account
  belongs_to :conversation
  belongs_to :user

  before_validation { self.account_id ||= conversation&.account_id }

  # Met le fil dans une pile (on: true) ou l'en retire, pour cette personne seulement.
  def self.put!(conversation, user, stack, on: true)
    raise ArgumentError, "pile : reply_later ou set_aside" unless stack.in?(STACKS)

    state = find_or_initialize_by(conversation: conversation, user: user)
    column = COLUMNS.fetch(stack)
    state.update!(column => (on ? state[column] || Time.current : nil))
    state
  end
end
