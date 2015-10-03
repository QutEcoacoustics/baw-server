class CreatePermissions < ActiveRecord::Migration
  def change
    create_table :permissions do |t|
      t.integer :creator_id, null: false
      t.string  :level, null: false, limit: 255
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.integer :updater_id

      t.timestamps null: true
    end
  end
end
