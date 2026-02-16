# frozen_string_literal: true

class AddTopNFiltering < ActiveRecord::Migration[7.0]
  def change
    add_column :audio_event_import_files, :include_top, :integer, null: true,
      comment: 'Limit import to the top N results per tag per file'
    add_column :audio_event_import_files, :include_top_per, :integer, null: true,
      comment: 'Apply top filtering per this interval, in seconds'

    add_column :scripts, :event_import_include_top, :integer, null: true,
      comment: 'Limit import to the top N results per tag per file'
    add_column :scripts, :event_import_include_top_per, :integer, null: true,
      comment: 'Apply top filtering per this interval, in seconds'

    add_column :analysis_jobs_scripts, :event_import_include_top, :integer, null: true,
      comment: 'Limit import to the top N results per tag per file, custom to this analysis job'
    add_column :analysis_jobs_scripts, :event_import_include_top_per, :integer, null: true,
      comment: 'Apply top filtering per this interval, in seconds, custom to this analysis job'
  end
end
