class AddCancelStartedAtToAnalysisJobsItems < ActiveRecord::Migration[4.2]
  def change
    add_column :analysis_jobs_items, :cancel_started_at, :datetime,  null: true
  end
end
