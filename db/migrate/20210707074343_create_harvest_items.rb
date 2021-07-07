# frozen_string_literal: true

class CreateHarvestItems < ActiveRecord::Migration[6.1]
  def change
    create_table :harvest_items do |t|
      t.string :path
      t.string :status
      t.jsonb :info

      t.integer :audio_recording_id, null: true
      t.integer :uploader_id, null: false

      t.timestamps
    end
    add_index :harvest_items, :status
    add_index :harvest_items, :path

    add_foreign_key :harvest_items, :audio_recordings
    add_foreign_key :harvest_items, :users, column: :uploader_id
  end
end
