# frozen_string_literal: true

require_relative '../migration_helpers'

# adds cascade deletes to foreign keys for missing tables
class AddCascadeDeletes < ActiveRecord::Migration[7.2]
  include MigrationsHelpers

  def change
    [
      get_foreign_key(:sites, :region_id),
      get_foreign_key(:projects_sites, :site_id),
      get_foreign_key(:audio_recordings, :site_id),
      get_foreign_key(:audio_events, :audio_recording_id),
      get_foreign_key(:bookmarks, :audio_recording_id),
      get_foreign_key(:analysis_jobs_items, :audio_recording_id),
      get_foreign_key(:audio_recording_statistics, :audio_recording_id),
      get_foreign_key(:dataset_items, :audio_recording_id),
      get_foreign_key(:audio_event_import_files, :analysis_jobs_item_id),
      get_foreign_key(:progress_events, :dataset_item_id),
      get_foreign_key(:responses, :dataset_item_id),
      get_foreign_key(:harvests, :project_id),
      get_foreign_key(:harvest_items, :harvest_id),
      get_foreign_key(:harvest_items, :audio_recording_id),
      get_foreign_key(:analysis_jobs, :project_id),
      get_foreign_key(:analysis_jobs_scripts, :analysis_job_id),
      get_foreign_key(:analysis_jobs_items, :analysis_job_id),
      get_foreign_key(:regions, :project_id),
      get_foreign_key(:permissions, :project_id),
      get_foreign_key(:projects_saved_searches, :project_id)

    ].each do |fk|
      alter_foreign_key_cascade(fk, on_delete_cascade: true)
    end
  end
end
