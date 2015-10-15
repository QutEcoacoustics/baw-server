class ChangeMiscColumns < ActiveRecord::Migration
  def up
    change_column :tags, :type_of_tag, :string, null: false, default: 'general'
    change_column :scripts, :created_at, :datetime, null: false
    change_column :audio_events, :creator_id, :integer, null: false
    change_column :audio_events_tags, :creator_id, :integer, null: false
    change_column :audio_recordings, :creator_id, :integer, null: false
    change_column :bookmarks, :creator_id, :integer, null: false
    change_column :permissions, :creator_id, :integer, null: false
    change_column :projects, :creator_id, :integer, null: false
    change_column :tags, :creator_id, :integer, null: false
  end

  def down
    change_column :tags, :type_of_tag, :string, null: false
    change_column :scripts, :created_at, :datetime
    change_column :audio_events, :creator_id, :integer
    change_column :audio_events_tags, :creator_id, :integer
    change_column :audio_recordings, :creator_id, :integer
    change_column :bookmarks, :creator_id, :integer
    change_column :permissions, :creator_id, :integer
    change_column :projects, :creator_id, :integer
    change_column :tags, :creator_id, :integer
  end
end
