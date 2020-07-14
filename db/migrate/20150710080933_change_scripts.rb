class ChangeScripts < ActiveRecord::Migration[4.2]
  def change
    reversible do |direction|
      direction.up do
        remove_column :scripts, :notes

        remove_column :scripts, :settings_file_file_name
        remove_column :scripts, :settings_file_content_type
        remove_column :scripts, :settings_file_file_size
        remove_column :scripts, :settings_file_updated_at

        remove_column :scripts, :data_file_file_name
        remove_column :scripts, :data_file_content_type
        remove_column :scripts, :data_file_file_size
        remove_column :scripts, :data_file_updated_at

        add_column :scripts, :executable_command, :text, null: false
        add_column :scripts, :executable_settings, :text, null: false
      end
      direction.down do
        add_column :scripts, :notes, :text

        add_column :scripts, :settings_file_file_name, :string
        add_column :scripts, :settings_file_content_type, :string
        add_column :scripts, :settings_file_file_size, :integer
        add_column :scripts, :settings_file_updated_at, :datetime

        add_column :scripts, :data_file_file_name, :string
        add_column :scripts, :data_file_content_type, :string
        add_column :scripts, :data_file_file_size, :integer
        add_column :scripts, :data_file_updated_at, :datetime

        remove_column :scripts, :executable_command, :text, null: false
        remove_column :scripts, :executable_settings, :text, null: false
      end
    end
  end
end
