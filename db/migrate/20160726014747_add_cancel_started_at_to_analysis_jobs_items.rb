class AddCancelStartedAtToAnalysisJobsItems < ActiveRecord::Migration
  def change
    add_column :analysis_jobs_items, :cancel_started_at, :datetime,  null: true
  end
end
