class CreateBookmarks < ActiveRecord::Migration
  def change
    create_table :bookmarks do |t|
      t.integer :audio_recording_id
      t.decimal :offset_seconds
      t.string :name
      t.text :notes
      t.integer  :creator_id   , :null => false
      t.integer  :updater_id

      t.timestamps
    end
  end
end
