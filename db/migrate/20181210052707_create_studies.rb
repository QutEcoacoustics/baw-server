class CreateStudies < ActiveRecord::Migration
  def change
    create_table :studies do |t|

      t.integer :creator_id
      t.integer :updater_id
      t.integer :dataset_id
      t.string :name
      t.timestamps null: false
    end

    add_foreign_key :studies, :datasets
    add_foreign_key :studies, :users, column: :creator_id
    add_foreign_key :studies, :users, column: :updater_id

  end
end
