# Une discussion avec son agent, dans un client, souvent née d'un fil. Personne d'autre ne la voit.
# Effacée après 90 jours sans activité (décision A8).
class AgentChat < ApplicationRecord
  STATUSES = %w[idle running waiting failed].freeze
  RETENTION = 90.days

  acts_as_tenant :account
  belongs_to :user
  belongs_to :conversation, optional: true
  has_many :agent_messages, -> { order(:id) }, dependent: :destroy, inverse_of: :agent_chat
  has_many :agent_actions, -> { order(:id) }, dependent: :destroy, inverse_of: :agent_chat

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(updated_at: :desc, id: :desc) }

  def self.purge_old! = where(updated_at: ...RETENTION.ago).destroy_all

  def running? = status == "running"
  def waiting? = status == "waiting"

  # Le message de la personne ; l'agent répond en tâche de fond.
  def ask!(text)
    raise ArgumentError, "Le message est vide." if text.blank?
    raise ArgumentError, "L'agent répond encore, un instant." if running?
    raise ArgumentError, "Confirme ou refuse d'abord les actions en attente." if waiting?

    transaction do
      agent_messages.create!(role: "user", content: [ { "type" => "text", "text" => text.strip } ])
      update!(status: "running", error: nil, title: title.presence || text.squish.truncate(80))
    end
    AgentRunJob.perform_later(self)
  end

  # Confirmer ou refuser une action en attente ; quand plus rien n'attend, l'agent reprend.
  def decide!(action, confirm:, user:)
    raise ArgumentError, "Cette action a déjà été traitée." unless action.pending?

    resume = transaction do
      action.update!(status: confirm ? "confirmed" : "rejected", decided_by: user, decided_at: Time.current)
      agent_actions.pending.none?.tap { |none_left| update!(status: "running") if none_left }
    end
    AgentRunJob.perform_later(self, resume: true) if resume
  end

  # Ce que la personne voit : ses messages, le texte de l'agent et les actions, dans l'ordre.
  def transcript
    actions = agent_actions.to_a.group_by(&:agent_message_id)
    agent_messages.flat_map do |message|
      if message.role == "user"
        message.text.present? ? [ [ :user, message.text ] ] : []
      else
        [ ([ :agent, message.text ] if message.text.present?), *actions.fetch(message.id, []).select(&:writes?).map { |action| [ :action, action ] } ].compact
      end
    end
  end

  def broadcast_refresh = Turbo::StreamsChannel.broadcast_refresh_to(self)
end
