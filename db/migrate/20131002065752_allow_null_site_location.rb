class AllowNullSiteLocation < ActiveRecord::Migration[4.2]
  def up
    change_column :sites, :longitude, :decimal, :null => true
    change_column :sites, :latitude, :decimal, :null => true
  end

  def down
    change_column :sites, :longitude, :decimal, :null => false
    change_column :sites, :latitude, :decimal, :null => false
  end
end
