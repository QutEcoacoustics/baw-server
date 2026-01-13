class AddMigrations < ActiveRecord::Migration[8.0]
  def change
    add_index :audio_recordings, :file_hash

    reversible do |dir|
      dir.up do
        execute 'DROP INDEX IF EXISTS audio_recordings_icase_file_hash_idx;'
        execute 'DROP INDEX IF EXISTS audio_recordings_icase_file_hash_id_idx;'
      end

      dir.down do
        execute 'CREATE INDEX audio_recordings_icase_file_hash_idx ON audio_recordings ((LOWER(file_hash)));'
        execute 'CREATE INDEX audio_recordings_icase_file_hash_id_idx ON audio_recordings ((LOWER(file_hash)), id);'
      end
    end
  end
end
