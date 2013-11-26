class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string   :text         , :null => false
      t.boolean  :is_taxanomic , :null => false, :default => false
      t.string   :type_of_tag  , :null => false
      t.boolean  :retired      , :null => false, :default => false
      t.text     :notes

      t.timestamps
      t.userstamps
    end
    create_table :audio_events_tags do |t|
      t.integer :audio_event_id, :null => false
      t.integer :tag_id, :null => false

      t.timestamps
      t.userstamps
    end
    add_index :audio_events_tags, [:audio_event_id, :tag_id], :unique => true
  end
end
