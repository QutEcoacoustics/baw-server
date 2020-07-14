class CreateDatasets < ActiveRecord::Migration[4.2]
  def change
    create_table :datasets do |t|
      t.string :name, :null => false
      t.time :start_time
      t.time :end_time
      t.date :start_date
      t.date :end_date
      t.string  :filters
      t.integer :number_of_samples
      t.integer :number_of_tags
      t.string  :types_of_tags
      t.text    :description
      t.integer :creator_id, :null => false
      t.integer :updater_id
      t.integer :project_id, :null => false
      t.timestamps null: true
    end
  end
end
