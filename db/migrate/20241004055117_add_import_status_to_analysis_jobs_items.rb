# frozen_string_literal: true

class AddImportStatusToAnalysisJobsItems < ActiveRecord::Migration[7.2]
  def change
    add_column(
      :analysis_jobs_items, :import_success, :bool, null: true,
      comment: 'Did importing audio events succeed?'
    )
  end
end
