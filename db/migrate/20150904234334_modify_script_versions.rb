class ModifyScriptVersions < ActiveRecord::Migration
  def change
    reversible do |direction|
      direction.up do
        remove_index :scripts, name: 'scripts_updated_by_script_id_uidx'
        remove_index :scripts, :updated_by_script_id
        remove_foreign_key :scripts, column: :updated_by_script_id, name: 'scripts_updated_by_script_id_fk'

        rename_column :scripts, :updated_by_script_id, :group_id

        add_index :scripts, :group_id
        add_foreign_key :scripts, :scripts, column: :group_id, name: 'scripts_group_id_fk'
      end
      direction.down do
        remove_index :scripts, :group_id
        remove_foreign_key :scripts, column: :group_id, name: 'scripts_group_id_fk'

        rename_column :scripts, :group_id, :updated_by_script_id

        add_index :scripts, :updated_by_script_id
        add_index :scripts, :updated_by_script_id, name: 'scripts_updated_by_script_id_uidx', unique: true
        add_foreign_key :scripts, :scripts, column: :updated_by_script_id, name: 'scripts_updated_by_script_id_fk'
      end
    end
  end
end
