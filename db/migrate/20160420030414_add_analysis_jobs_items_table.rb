class AddAnalysisJobsItemsTable < ActiveRecord::Migration[4.2]
  def change
    create_table :analysis_jobs_items do |t|

      t.references :analysis_job, foreign_key: true, index: true, null: false
      t.references :audio_recording, foreign_key: true, index: true, null: false

      t.string :queue_id, null: true, limit: 255
      t.string :status, null: false, limit: 255, default: 'new'

      t.datetime :created_at, null: false
      t.datetime :queued_at, null: true
      t.datetime :work_started_at, null: true
      t.datetime :completed_at, null: true

    end

    add_index(:analysis_jobs_items, :queue_id, unique: true, name: 'queue_id_uidx')
  end
end
