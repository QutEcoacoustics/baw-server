class CreateJobs < ActiveRecord::Migration[4.2]
  def change
    create_table :jobs do |t|
      t.string :name              , :null => false
      t.string :annotation_name
      t.text :custom_settings
      t.integer :dataset_id       , :null => false
      t.integer :script_id        , :null => false
      t.integer :creator_id       , :null => false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at

      t.timestamps null: true
    end
  end
end
