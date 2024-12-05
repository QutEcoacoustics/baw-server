# frozen_string_literal: true

require_relative '../migration_helpers'

# Further tweaks to analysis jobs to support our new infrastructure
class AnalysisJobsRedesign < ActiveRecord::Migration[7.0]
  include MigrationsHelpers

  def change
    change_table :analysis_jobs do |t|
      t.jsonb :filter,
        comment: 'API filter to include recordings in this job. If blank then all recordings are included.'
      t.boolean :system_job, default: false, null: false,
        comment: 'If true this job is automatically run and not associated with a single project. We can have multiple system jobs.'
      t.boolean :ongoing, default: false, null: false,
        comment: 'If true the filter for this job will be evaluated after a harvest. If more items are found the job will move to the processing stage if needed and process the new recordings.'
      t.references :project, null: true, foreign_key: true, type: :integer,
        comment: 'Project this job is associated with. This field simply influences which jobs are shown on a project page.'

      t.integer :retry_count, default: 0, null: false,
        comment: 'Count of retries'
      t.integer :amend_count, default: 0, null: false,
        comment: 'Count of amendments'
      t.integer :suspend_count, default: 0, null: false,
        comment: 'Count of suspensions'
      t.integer :resume_count, default: 0, null: false,
        comment: 'Count of resumptions'

      # surpassed by the filter column
      t.remove :saved_search_id, type: :integer

      # surpassed by the analysis_jobs_scripts table
      t.remove :script_id, type: :integer
      t.remove :custom_settings, type: :text

      # no longer needed - analysis jobs items are now tracked in their own table
      # so we don't need to cache  the stats
      t.remove :overall_progress, type: :json
      t.remove :overall_progress_modified_at, type: :datetime
    end

    # allow for running more than one script in an analysis
    create_join_table :analysis_jobs, :scripts, column_options: { type: :integer } do |t|
      t.text :custom_settings, comment: 'Custom settings for this script and analysis job'
    end
    alter_primary_key_constraint :analysis_jobs_scripts, [:analysis_job_id, :script_id]

    reversible do |dir|
      # potential to get n recordings by m analyses by o scripts here
      dir.up do
        create_enum :analysis_jobs_item_status, ['new', 'queued', 'working', 'finished']
        create_enum :analysis_jobs_item_result, ['success', 'failed', 'killed', 'cancelled']
        create_enum :analysis_jobs_item_transition, ['queue', 'retry', 'cancel', 'finish']

        change_column :analysis_jobs_items, :id, :bigint
        change_column_default :analysis_jobs_items, :status, nil
        change_column :analysis_jobs_items, :status, :enum, enum_type: :analysis_jobs_item_status, null: false,
          comment: 'Current status of this job item', using: 'status::analysis_jobs_item_status'
        change_column_default :analysis_jobs_items, :status, 'new'
      end
      dir.down do
        change_column :analysis_jobs_items, :id, :integer
        change_column :analysis_jobs_items, :status, :string, null: false, default: 'new'

        remove = <<~SQL.squish
          DROP TYPE analysis_jobs_item_status CASCADE;
          DROP TYPE analysis_jobs_item_result CASCADE;
          DROP TYPE analysis_jobs_item_transition CASCADE;
        SQL

        execute(remove)
      end
    end

    change_table :analysis_jobs_items do |t|
      t.references :script, null: false, foreign_key: true, type: :integer, comment: 'Script used for this item'
      t.integer :attempts, null: false, default: 0, comment: 'Number of times this job item has been attempted'
      t.enum :transition, enum_type: :analysis_jobs_item_transition,
        comment: 'The pending transition to apply to this item. Any high-latency action should be done via transition and on a worker rather than in a web request.'
      t.enum :result, enum_type: :analysis_jobs_item_result, comment: 'Result of this job item'
      t.text :error, comment: 'Error message if this job item failed'
      t.integer :used_walltime_seconds, comment: 'Walltime used by this job item'
      t.integer :used_memory_bytes, comment: 'Memory used by this job item'
      t.rename :completed_at, :finished_at
    end

    # seems big int is the default now for ids and we really don't need that for this table
    create_table :provenances, id: :integer do |t|
      t.string :name
      t.string :version
      t.string :url
      t.text :description, comment: 'Markdown description of this source'
      t.decimal :score_minimum, comment: 'Lower bound for scores emitted by this source, if known'
      t.decimal :score_maximum, comment: 'Upper bound for scores emitted by this source, if known'

      t.integer :creator_id
      t.integer :updater_id
      t.integer :deleter_id
      t.timestamps
      t.datetime :deleted_at
    end

    change_table :audio_events do |t|
      t.references :provenance, null: true, foreign_key: true, type: :integer, comment: 'Source of this event'

      t.decimal :score, null: true, comment: 'Score or confidence for this event.'

      # this allows us to specify full-bandwidth events
      t.change_null(:low_frequency_hertz, true)
    end

    change_table :audio_event_imports do |t|
      t.references :analysis_job, null: true, foreign_key: true, type: :integer,
        comment: 'Analysis job that created this import'
    end

    change_table :scripts do |t|
      # ~~I have no idea what analysis_action_params is for, but it's not used anywhere~~
      # analysis_action_params was used as a way to template in extra parameters into the executable command,
      # or to specify additional actions to take after a job (copy extra files etc).
      # It is complicated though, so let's try without it
      t.remove :analysis_action_params, type: :json
      t.jsonb :resources, null: true, comment: 'Resources required by this script in the PBS format.'
    end

    change_table :user_statistics do |t|
      t.decimal :analyzed_audio_duration, default: 0, null: false
    end

    # missing from previous migration
    reversible do |dir|
      dir.up do
        add_foreign_key :audio_events, :audio_event_imports, on_delete: :nullify
      end
      dir.down do
        remove_foreign_key :audio_events, :audio_event_imports
      end
    end

    add_foreign_key :analysis_jobs_scripts, :analysis_jobs
    add_foreign_key :analysis_jobs_scripts, :scripts

    add_foreign_key :provenances, :users, column: :creator_id
    add_foreign_key :provenances, :users, column: :updater_id
    add_foreign_key :provenances, :users, column: :deleter_id

    # ensure we don't have duplicate job items
    add_index(
      :analysis_jobs_items,
      [:analysis_job_id, :script_id, :audio_recording_id],
      unique: true,
      name: 'index_analysis_jobs_items_are_unique'
    )
  end
end
