# Reply Later et Set Aside, façon Hey : chaque personne met un fil de côté ou le garde pour y répondre
# plus tard, sans changer la vue des autres. Un fil dans l'une de ces piles quitte sa pile habituelle.
class CreateConversationStates < ActiveRecord::Migration[8.1]
  def up
    create_table :conversation_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :reply_later_at
      t.datetime :set_aside_at
      t.timestamps
    end
    add_index :conversation_states, %i[conversation_id user_id], unique: true

    condition = "current_setting('sg_mail.bypass_rls', true) = 'on' " \
      "OR account_id = NULLIF(current_setting('sg_mail.account_id', true), '')::bigint"
    execute <<~SQL
      ALTER TABLE conversation_states ENABLE ROW LEVEL SECURITY;
      ALTER TABLE conversation_states FORCE ROW LEVEL SECURITY;
      CREATE POLICY account_isolation ON conversation_states USING (#{condition}) WITH CHECK (#{condition});
    SQL
  end

  def down
    drop_table :conversation_states
  end
end
