class ChangeAudioRecordingDataLengthBytesLimit < ActiveRecord::Migration
  def up
    change_column :audio_recordings, :data_length_bytes, :integer, null: false, limit: 8
  end

  def down
    change_column :audio_recordings, :data_length_bytes, :integer, null: false, limit: 4
  end
end
