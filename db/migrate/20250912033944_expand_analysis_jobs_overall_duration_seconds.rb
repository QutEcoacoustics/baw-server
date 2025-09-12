class ExpandAnalysisJobsOverallDurationSeconds < ActiveRecord::Migration[8.0]
  def up
    # this becomes an inexact value, but it doesn't really matter since we basically
    # just need order of magnitude correctness to estimate total duration analyzed
    change_column :analysis_jobs, :overall_duration_seconds, 'DOUBLE PRECISION'
  end

  def down
    change_column :analysis_jobs, :overall_duration_seconds, :decimal, precision: 14, scale: 4
  end
end
