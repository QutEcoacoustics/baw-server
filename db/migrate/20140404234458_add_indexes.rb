class AddIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index  :audio_recordings, [:created_at , :updated_at], name: 'audio_recordings_created_updated_at'
    add_index  :audio_recordings, :site_id
  end
end
