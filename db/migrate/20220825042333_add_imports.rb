# frozen_string_literal: true

# add import table for audio events
class AddImports < ActiveRecord::Migration[7.0]
  def change
    create_table :audio_event_imports do |t|
      t.string :name
      t.jsonb :files
      t.text :description

      t.integer :creator_id
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at
      t.timestamps
    end

    change_table :audio_events do |t|
      t.integer :audio_event_import_id, null: true
      t.jsonb :context, null: true
      t.integer :channel, null: true
    end
  end
end
