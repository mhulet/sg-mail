class Current < ActiveSupport::CurrentAttributes
  attribute :session, :membership
  delegate :account, to: :membership, allow_nil: true

  # Session du navigateur, ou, pour l'API et le MCP, la personne derrière le jeton.
  def user = session ? session.user : membership&.user
end
