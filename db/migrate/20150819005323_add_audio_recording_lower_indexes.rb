class AddAudioRecordingLowerIndexes < ActiveRecord::Migration[4.2]
  def up
    execute 'CREATE INDEX audio_recordings_icase_file_hash_idx ON audio_recordings ((LOWER(file_hash)));'
    execute 'CREATE INDEX audio_recordings_icase_uuid_idx ON audio_recordings ((LOWER(uuid)));'
    execute 'CREATE INDEX audio_recordings_icase_file_hash_id_idx ON audio_recordings ((LOWER(file_hash)), id);'
    execute 'CREATE INDEX audio_recordings_icase_uuid_id_idx ON audio_recordings ((LOWER(uuid)), id);'
  end

  def down
    execute 'DROP INDEX IF EXISTS audio_recordings_icase_file_hash_idx;'
    execute 'DROP INDEX IF EXISTS audio_recordings_icase_uuid_idx;'
    execute 'DROP INDEX IF EXISTS audio_recordings_icase_file_hash_id_idx;'
    execute 'DROP INDEX IF EXISTS audio_recordings_icase_uuid_id_idx;'
  end
end
