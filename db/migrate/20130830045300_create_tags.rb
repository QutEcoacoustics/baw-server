class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string :text, null: false, limit: 255
      t.boolean :is_taxanomic, null: false, default: false
      t.string :type_of_tag, null: false, limit: 255
      t.boolean :retired, null: false, default: false
      t.text :notes
      t.integer :creator_id, null: false
      t.integer :updater_id

      t.timestamps null: true
    end
    create_table :audio_events_tags do |t|
      t.integer :audio_event_id, null: false
      t.integer :tag_id, null: false
      t.integer :creator_id, null: false
      t.integer :updater_id

      t.timestamps null: true
    end
    add_index :audio_events_tags, [:audio_event_id, :tag_id], unique: true
  end
end
