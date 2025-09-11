# frozen_string_literal: true

class AddScoreThresholds < ActiveRecord::Migration[7.0]
  def change
    add_column :audio_event_import_files, :minimum_score, :numeric, null: true,
      comment: 'Minimum score threshold actually used'
    add_column :audio_event_import_files, :imported_count, :integer, null: false, default: 0,
      comment: 'Number of events parsed minus rejections'
    add_column :audio_event_import_files, :parsed_count, :integer, null: false, default: 0,
      comment: 'Number of events parsed from this file'
    add_column :scripts, :event_import_minimum_score, :numeric, null: true,
      comment: 'Minimum score threshold for importing events, if any'
    add_column :analysis_jobs_scripts, :event_import_minimum_score, :numeric, null: true,
      comment: 'Minimum score threshold for importing events, if any, custom to this analysis job'

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE audio_event_import_files
          SET
            imported_count = sub.count,
            parsed_count = sub.count
          FROM (
            SELECT audio_event_import_file_id, COUNT(*) AS count
            FROM audio_events
            WHERE audio_event_import_file_id IS NOT NULL
            GROUP BY audio_event_import_file_id
          ) AS sub
          WHERE audio_event_import_files.id = sub.audio_event_import_file_id
        SQL
      end
    end
  end
end
