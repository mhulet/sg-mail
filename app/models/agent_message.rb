# Un tour de la discussion, tel qu'il part chez Claude ou en revient (blocs de contenu), avec son coût.
class AgentMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  acts_as_tenant :account
  belongs_to :agent_chat, touch: true
  has_many :agent_actions, dependent: :destroy

  validates :role, inclusion: { in: ROLES }

  scope :this_month, -> { where(created_at: Time.current.all_month) }

  # Le texte visible : les blocs « text » seulement (ni réflexion, ni outils, ni résultats d'outils).
  def text = content.select { |block| block["type"] == "text" }.map { |block| block["text"] }.join("\n\n").strip

  def tool_uses = content.select { |block| block["type"] == "tool_use" }

  def to_claude = { role: role, content: content }
end
