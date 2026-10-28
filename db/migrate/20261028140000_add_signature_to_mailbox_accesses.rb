# Par personne et par boîte : la signature ajoutée aux messages, et le nom affiché à l'envoi
# (« Semisto Academy » pour formations@, par exemple).
class AddSignatureToMailboxAccesses < ActiveRecord::Migration[8.1]
  def change
    add_column :mailbox_accesses, :signature, :text
    add_column :mailbox_accesses, :sender_name, :string
  end
end
