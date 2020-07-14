class AddExtraScriptsFields < ActiveRecord::Migration[4.2]
  def change

    # extra options to be passed to actions as part of hash when creating actions
    add_column :scripts, :analysis_action_params, :JSON
  end
end
