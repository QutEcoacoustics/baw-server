class AddLicenseAndAttributionToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :licence_spec, :text
    add_column :projects, :attribution_cite, :text
  end
end
