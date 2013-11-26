class AddOriginalFileNameToAudioRecording < ActiveRecord::Migration
  def change
    add_column :audio_recordings, :original_file_name, :string
  end
end
