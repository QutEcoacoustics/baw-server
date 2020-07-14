class AnalysisJobsColumnChanges < ActiveRecord::Migration[4.2]
  def change

    # playing with the state machines, we don't want defaults set
    change_column_default :analysis_jobs, :overall_status, nil

    # make use of new JSON support in rails
    change_column :analysis_jobs, :overall_progress, :JSON, {cast_as: 'json'}
  end
end
