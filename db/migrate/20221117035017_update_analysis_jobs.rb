# frozen_string_literal: true

# Relaxes some of our assumptions for how analysis jobs should work
class UpdateAnalysisJobs < ActiveRecord::Migration[7.0]
  def change
    remove_column :analysis_jobs, :annotation_name, :string
    change_column_null :analysis_jobs, :saved_search_id, true
    change_column_null :analysis_jobs, :custom_settings, true

    change_column_null :scripts, :executable_settings, true
    change_column_null :scripts, :executable_settings_media_type, true

    add_column :scripts, :executable_settings_name, :string, null: true
  end
end
