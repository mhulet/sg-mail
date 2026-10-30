# Un client de Super Génial (Semisto, Silvéa…). Tout ce qui touche aux emails lui appartient.
class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy

  validates :name, presence: true

  # Tables qui appartiennent au client, dans un ordre qui respecte leurs clés étrangères.
  OWNED_TABLES = %w[
    integration_connections integrations agent_actions agent_messages agent_chats readings access_logs notes drafts conversation_states screenings messages conversations mail_folders
    mailbox_accesses mailboxes oauth_tokens oauth_authorization_codes api_tokens invitations memberships
  ].freeze

  # Suppression complète du client, à sa demande (cadrage §4.2) : boîtes, emails, tâches, notes, jetons,
  # membres. L'accès Google de chaque boîte Gmail est révoqué. Irréversible.
  def purge!
    gmail_mailboxes = Tenancy.with_account(self) do
      mailboxes = Mailbox.where(provider: "gmail").to_a
      transaction do
        OWNED_TABLES.each { |table| self.class.connection.delete("DELETE FROM #{table} WHERE account_id = #{id.to_i}") }
        self.class.where(id: id).delete_all
      end
      mailboxes
    end
    # Hors du client, qui n'existe plus : le job ne doit pas le recharger.
    ActsAsTenant.without_tenant { gmail_mailboxes.each(&:revoke_google_access) }
  end
end
