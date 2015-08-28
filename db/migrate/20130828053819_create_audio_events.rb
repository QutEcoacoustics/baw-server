class CreateAudioEvents < ActiveRecord::Migration
  def change
    create_table :audio_events do |t|
      t.integer :audio_recording_id       , :null => false
      t.decimal :start_time_seconds       , :null => false
      t.decimal :end_time_seconds
      t.decimal :low_frequency_hertz      , :null => false
      t.decimal :high_frequency_hertz
      t.boolean :is_reference             , :null => false, :default => false
      t.integer :creator_id
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at

      t.timestamps null: true
    end
  end
end
