# Les tâches vivent dans les outils de chaque client (My Semisto, Claudy…), que l'agent atteint : SG Mail n'en
# garde plus. Les tâches existantes sont effacées.
class DropTasks < ActiveRecord::Migration[8.1]
  def up
    drop_table :tasks
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
