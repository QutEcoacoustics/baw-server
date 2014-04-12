class CreateAnnotationDiscussions < ActiveRecord::Migration
  def change
    create_table :annotation_discussions do |t|

      t.integer :audio_event_id, null: false
      t.text :comment, null:false
      t.string :flag
      t.integer :flagger_id
      t.datetime :flagged_at

      t.integer :creator_id, null: false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at

      t.timestamps # :updated_at, :created_at
    end
  end
end
