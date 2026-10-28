# Archiver un fil, par personne : il quitte ma réception (et mes autres piles) jusqu'au prochain message.
class AddArchivedAtToConversationStates < ActiveRecord::Migration[8.1]
  def change
    add_column :conversation_states, :archived_at, :datetime
  end
end
