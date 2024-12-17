# frozen_string_literal: true

# Fix the scaling issue we had with the audio event import files table
# The files column was a jsonb column, which is not efficient for many files.
# Also storing context in audio_events is not efficient.
class AudioEventImportFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :audio_event_import_files do |t|
      t.references :audio_event_import, null: false, foreign_key: true, type: :integer

      t.references :analysis_jobs_item, null: true, foreign_key: true, type: :integer
      t.string :path, null: true,
        comment: 'Path to the file on disk, relative to the analysis job item. Not used for uploaded files'
      constraint = <<-SQL.squish
            (path IS NOT NULL AND analysis_jobs_item_id IS NOT NULL) OR
            (path IS NULL AND analysis_jobs_item_id IS NULL)
      SQL
      t.check_constraint constraint, name: 'path_and_analysis_jobs_item'

      t.column :additional_tag_ids, :integer, array: true, default: nil,
        comment: 'Additional tag ids applied for this import'

      t.datetime :created_at, precision: 6, null: false

      # Hudson says: because we have to migrate the data, and the previous data did not have a file_hash
      # we must allow nulls here. Sticking in a fake non-null value would be a bad idea.
      # Non-nullness will be enforced in the application.
      t.text :file_hash, null: true, comment: 'Hash of the file contents used for uniqueness checking'
    end

    change_table :audio_event_imports do |t|
      t.remove :files, type: :jsonb
    end

    change_table :audio_events do |t|
      t.remove :context, type: :jsonb

      t.integer :import_file_index, null: true, comment: 'Index of the row/entry in the file that generated this event'
    end

    reversible do |dir|
      dir.up do
        add_reference :audio_events, :audio_event_import_file, index: true, foreign_key: true

        # create a default audio_event_import_file for each audio_event_import
        query = <<~SQL.squish
          INSERT INTO audio_event_import_files (audio_event_import_id, created_at, path, file_hash)
          SELECT id, created_at, 'default', null FROM audio_event_imports;
        SQL

        execute(query)

        # update audio_events to point to the new audio_event_import_file
        query = <<~SQL.squish
          UPDATE audio_events
          SET audio_event_import_file_id = audio_event_import_files.id
          FROM audio_event_import_files
          WHERE audio_events.audio_event_import_id = audio_event_import_files.id
        SQL

        execute(query)

        # now remove the unnecessary columns
        remove_reference :audio_events, :audio_event_import, index: true
      end
      dir.down do
        add_reference :audio_events, :audio_event_import, index: true, foreign_key: true

        # update audio_events to point back to the audio_event_import
        query = <<~SQL.squish
          UPDATE audio_events
          SET audio_event_import_id = audio_event_import_files.audio_event_import_id
          FROM audio_event_import_files
          WHERE audio_events.audio_event_import_file_id = audio_event_import_files.id
        SQL

        execute(query)

        remove_reference :audio_events, :audio_event_import_file, index: true, foreign_key: true
      end
    end

    # fixing up past mistakes
    change_column_null :audio_event_imports, :creator_id, false
    # add missing foreign key constraints
    add_foreign_key :audio_event_imports, :users, column: :creator_id, name: 'audio_event_imports_creator_id_fk'
    add_foreign_key :audio_event_imports, :users, column: :updater_id, name: 'audio_event_imports_updater_id_fk'
    add_foreign_key :audio_event_imports, :users, column: :deleter_id, name: 'audio_event_imports_deleter_id_fk'
  end
end
