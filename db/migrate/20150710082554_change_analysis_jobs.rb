class ChangeAnalysisJobs < ActiveRecord::Migration
  def change
    change_table :analysis_jobs do |t|
      t.rename :script_settings, :custom_settings

      t.datetime :started_at
      t.string :job_status, limit: 255, null:false, default: 'new'

    end
  end
end
