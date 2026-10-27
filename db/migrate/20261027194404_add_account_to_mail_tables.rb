# Les boîtes de la phase 0 n'ont pas de client : on les range dans un « Compte initial », à renommer.
class AddAccountToMailTables < ActiveRecord::Migration[8.1]
  TABLES = %i[mailboxes mail_folders messages].freeze

  def up
    TABLES.each { |table| add_reference table, :account, foreign_key: true }

    if select_value("SELECT 1 FROM mailboxes LIMIT 1")
      account_id = select_value(<<~SQL)
        INSERT INTO accounts (name, created_at, updated_at) VALUES ('Compte initial', now(), now()) RETURNING id
      SQL
      execute "UPDATE mailboxes SET account_id = #{account_id.to_i}"
      execute "UPDATE mail_folders SET account_id = mailboxes.account_id FROM mailboxes WHERE mailboxes.id = mail_folders.mailbox_id"
      execute "UPDATE messages SET account_id = mailboxes.account_id FROM mailboxes WHERE mailboxes.id = messages.mailbox_id"
    end

    TABLES.each { |table| change_column_null table, :account_id, false }

    remove_index :mailboxes, %i[provider address]
    add_index :mailboxes, %i[account_id provider address], unique: true
  end

  def down
    remove_index :mailboxes, %i[account_id provider address]
    add_index :mailboxes, %i[provider address], unique: true
    TABLES.each { |table| remove_reference table, :account, foreign_key: true }
  end
end
