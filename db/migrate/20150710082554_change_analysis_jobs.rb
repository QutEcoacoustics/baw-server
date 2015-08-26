class ChangeAnalysisJobs < ActiveRecord::Migration
  def change

    change_table :analysis_jobs do |t|
      t.rename :script_settings, :custom_settings

      t.datetime :started_at

      # prefixing with overall_ to avoid conflicts with built-in model attributes
      t.string :overall_status, null: false, default: 'new'
      t.datetime :overall_status_modified_at, null: false

      t.text :overall_progress, null: false
      t.datetime :overall_progress_modified_at, null: false

      t.integer :overall_count, null: false
      t.decimal :overall_duration_seconds, precision: 14, scale: 4, null: false # can hold 50 years in seconds

    end

    change_column_null :analysis_jobs, :custom_settings, false

  end
end
