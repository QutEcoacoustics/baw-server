class CreateProjectSite < ActiveRecord::Migration
  def change
    create_table :projects_sites, id: false do |t|
      t.integer :project_id, :null => false
      t.integer :site_id, :null => false
    end
  end

end
