# « Lu par… » : une ligne par personne et par message. Indépendant du drapeau « lu » de
# Gmail ou du serveur IMAP, qu'on ne touche pas (décision D4).
class Reading < ApplicationRecord
  acts_as_tenant :account
  belongs_to :message
  belongs_to :user

  # Marque lus tous les messages du périmètre, en une requête.
  def self.mark!(user, messages)
    scope = messages.unscope(:order).where.not(id: where(user: user).select(:message_id))
    sql = scope.select(:account_id, :id, connection.quote(user.id), "now()").to_sql
    connection.execute("INSERT INTO readings (account_id, message_id, user_id, read_at) #{sql} ON CONFLICT DO NOTHING")
  end
end
