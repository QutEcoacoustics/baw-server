class CreateExports < ActiveRecord::Migration[8.0]
  def change
    create_enum :export_status, ['pending', 'queued', 'working', 'ready', 'failed']

    create_table :exports do |t|
      t.string     :name

      t.jsonb      :filter, null: false
      t.boolean    :obfuscate_locations

      t.string     :export_type, limit: 16, null: false
      t.jsonb      :options, comment: 'Additional options for the export'

      t.column     :status, :export_status, null: false, default: 'pending'
      t.text       :error, comment: 'User visible error message if the export failed'

      t.datetime   :started_at
      t.datetime   :finished_at
      t.datetime   :expires_at

      t.boolean    :purged

      t.integer    :download_count, default: 0

      t.references :creator, null: false, foreign_key: { to_table: :users }

      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
