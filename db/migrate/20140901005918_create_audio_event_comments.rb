class CreateAudioEventComments < ActiveRecord::Migration
  def change
    create_table :audio_event_comments do |t|
      t.integer :audio_event_id, null: false
      t.text :comment, null: false
      t.string :flag, limit: 255
      t.text :flag_explain

      t.integer :flagger_id
      t.datetime :flagged_at

      t.integer :creator_id, null: false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at

      t.timestamps null: true
    end
  end
end
