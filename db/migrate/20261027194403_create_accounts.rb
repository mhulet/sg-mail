class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :memberships, %i[account_id user_id], unique: true

    create_table :invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email_address, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :invitations, :token, unique: true
  end
end
