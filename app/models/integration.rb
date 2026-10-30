# Un outil du client (My Semisto, Claudy, l'admin d'un site…) que l'agent peut utiliser : son serveur MCP,
# déclaré par un admin. Chaque membre y connecte son propre compte (IntegrationConnection).
class Integration < ApplicationRecord
  acts_as_tenant :account
  has_many :connections, class_name: "IntegrationConnection", dependent: :delete_all

  validates :name, presence: true, length: { maximum: 40 }
  validates :slug, presence: true, uniqueness: { scope: :account_id, message: "ressemble trop à celui d'un autre outil" }
  validates :mcp_url, presence: true, format: { with: %r{\Ahttps://[^\s/]+[^\s]*\z}, message: "doit commencer par https://" }

  before_validation { self.slug = name.to_s.parameterize(separator: "_").delete("_").first(16).presence || "outil" if name_changed? || slug.blank? }

  scope :alphabetical, -> { order(:name) }

  def connection_for(user) = connections.find_by(user: user)
end
