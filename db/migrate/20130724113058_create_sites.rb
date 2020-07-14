class CreateSites < ActiveRecord::Migration[4.2]
  def change
    create_table :sites do |t|
      t.string  :name,        :null => false
      t.decimal :longitude,   :null => false
      t.decimal :latitude,    :null => false
      t.text    :notes
      t.integer :creator_id,  :null => false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at
      t.attachment :image

      t.timestamps null: true
    end
  end
end
