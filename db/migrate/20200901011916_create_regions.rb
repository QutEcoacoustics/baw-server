class CreateRegions < ActiveRecord::Migration[6.0]
  def change
    create_table :regions do |t|
      t.string :name
      t.text :description
      t.jsonb :notes

      t.integer :project_id, null: false

      t.integer :creator_id
      t.integer :updater_id
      t.integer :deleter_id

      t.timestamps null: true
      t.datetime :deleted_at
    end

    change_table :sites do |t|
      t.integer :region_id, null: true
    end

    add_foreign_key :regions, :projects
    add_foreign_key :regions, :users, column: :creator_id
    add_foreign_key :regions, :users, column: :updater_id
    add_foreign_key :regions, :users, column: :deleter_id
    add_foreign_key :sites, :regions
  end
end
