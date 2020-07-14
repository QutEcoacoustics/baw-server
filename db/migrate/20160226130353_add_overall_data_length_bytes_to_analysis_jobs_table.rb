class AddOverallDataLengthBytesToAnalysisJobsTable < ActiveRecord::Migration[4.2]
  def change
    add_column :analysis_jobs, :overall_data_length_bytes, :integer, limit: 8, null: false, default: 0
  end
end
