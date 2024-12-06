class AddLicenseToProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :projects, :license, :text
  end
end
