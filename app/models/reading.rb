# « Lu par… » : une ligne par personne et par message. Indépendant du drapeau « lu » de
# Gmail ou du serveur IMAP, qu'on ne touche pas (décision D4).
class Reading < ApplicationRecord
  acts_as_tenant :account
  belongs_to :message
  belongs_to :user

  # Marque lus tous les messages du périmètre, en une requête, et leurs copies reçues dans les autres
  # boîtes que cette personne voit (même Message-ID) : un email lu une fois est lu partout.
  def self.mark!(user, messages)
    messages = messages.unscope(:order)
    copies = Message.where(mailbox_id: Mailbox.accessible_by(user).select(:id),
      message_id_header: messages.where.not(message_id_header: nil).select(:message_id_header))
    scope = Message.where(id: messages.select(:id)).or(copies).where.not(id: where(user: user).select(:message_id))
    sql = scope.select(:account_id, :id, connection.quote(user.id), "now()").to_sql
    connection.execute("INSERT INTO readings (account_id, message_id, user_id, read_at) #{sql} ON CONFLICT DO NOTHING")
  end
end
