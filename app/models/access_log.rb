# Journal d'accès (cadrage §4.2) : qui a ouvert quel fil, téléchargé quelle pièce jointe, quand et par où.
# Visible des admins du client (« Membres » → « Journal d'accès »), effacé après un an.
class AccessLog < ApplicationRecord
  ACTIONS = { "open" => "a ouvert", "attachment" => "a téléchargé une pièce jointe de" }.freeze
  VIAS = { "web" => "SG Mail", "api" => "API ou CLI", "mcp" => "Claude (MCP)", "agent" => "Agent SG Mail" }.freeze
  RETENTION = 1.year

  acts_as_tenant :account
  belongs_to :user
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  validates :action, inclusion: { in: ACTIONS.keys }
  validates :via, inclusion: { in: VIAS.keys }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def self.record!(user, conversation, via:, action: "open", message: nil, detail: nil)
    create!(account_id: conversation.account_id, user: user, conversation: conversation, message: message,
      action: action, via: via, detail: detail&.truncate(200))
  end

  def self.purge_old! = where(created_at: ...RETENTION.ago).delete_all
end
