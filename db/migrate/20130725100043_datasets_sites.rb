class DatasetsSites < ActiveRecord::Migration
  def change
    create_table :datasets_sites, id: false do |t|
      t.integer :dataset_id, :null => false
      t.integer :site_id, :null => false
    end
  end
end
