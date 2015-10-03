class CreateDatasets < ActiveRecord::Migration
  def change
    create_table :datasets do |t|
      t.string :name, null: false, limit: 255
      t.time :start_time
      t.time :end_time
      t.date :start_date
      t.date :end_date
      t.string  :filters, limit: 255
      t.integer :number_of_samples
      t.integer :number_of_tags
      t.string  :types_of_tags, limit: 255
      t.text    :description
      t.integer :creator_id, null: false
      t.integer :updater_id
      t.integer :project_id, null: false
      t.timestamps null: true
    end
  end
end
