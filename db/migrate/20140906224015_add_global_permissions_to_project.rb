class AddGlobalPermissionsToProject < ActiveRecord::Migration
  def change
    add_column :projects, :anonymous_level, :string, default: 'none', null: false
    add_column :projects, :sign_in_level, :string, default: 'none', null: false
  end
end
