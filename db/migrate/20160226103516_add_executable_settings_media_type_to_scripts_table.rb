class AddExecutableSettingsMediaTypeToScriptsTable < ActiveRecord::Migration
  def change
    add_column :scripts, :executable_settings_media_type, :string, limit: 255, default: 'text/plain'
  end
end
