class AddOriginalFileNameToAudioRecording < ActiveRecord::Migration[4.2]
  def change
    add_column :audio_recordings, :original_file_name, :string
  end
end
