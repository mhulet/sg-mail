# Un même email envoyé à deux boîtes d'un client (communication@ et michael@) donne deux fils, un par boîte.
# root_message_id (le Message-ID du premier message du fil) les relie : la réception unifiée n'en montre qu'un.
class AddRootMessageIdToConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :conversations, :root_message_id, :string
    add_index :conversations, %i[account_id root_message_id]
    add_index :messages, %i[account_id message_id_header]

    execute "SET sg_mail.bypass_rls = 'on'"
    execute <<~SQL
      UPDATE conversations SET root_message_id = roots.message_id_header
      FROM (
        SELECT DISTINCT ON (conversation_id) conversation_id, message_id_header FROM messages
        WHERE conversation_id IS NOT NULL AND message_id_header IS NOT NULL
        ORDER BY conversation_id, sent_at NULLS LAST, id
      ) AS roots
      WHERE roots.conversation_id = conversations.id
    SQL
  ensure
    execute "RESET sg_mail.bypass_rls"
  end

  def down
    remove_index :messages, %i[account_id message_id_header]
    remove_column :conversations, :root_message_id
  end
end
