class DatasetsSites < ActiveRecord::Migration[4.2]
  def change
    create_table :datasets_sites, id: false do |t|
      t.integer :dataset_id, :null => false
      t.integer :site_id, :null => false
    end
  end
end
