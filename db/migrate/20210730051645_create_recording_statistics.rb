# frozen_string_literal: true

# Adds tables for tracking usage stats
class CreateRecordingStatistics < ActiveRecord::Migration[6.1]
  # a range of one day, at utc, example:
  # ["2021-08-02 00:00:00","2021-08-03 00:00:00")
  STATS_BUCKET_OPTIONS = {
    null: false,
    default: -> { "tsrange(CURRENT_DATE, CURRENT_DATE + (interval '1 day'))" }

  }.freeze

  def alter_range_constraint(table, column, with:, add: true)
    # Exclusion constraint prevents overlapping ranges
    # https://www.postgresql.org/docs/current/rangetypes.html#RANGETYPES-CONSTRAINT

    # we need both the indexes because
    # - must use a unique constraint to work with ON CONFLICT UPDATE 😠
    #   https://www.postgresql.org/docs/13/sql-insert.html
    # - and need the EXCLUSION constraint to ensure non-overlapping ranges
    # Ideally an exclusion constraint could be used as a uniqueness constraint

    # SET UNLGOGED disables the write ahead log - that is writing to disk before finishing the transaction.
    # Greatly improves write speed but at the risk of losing the most recent entries if the database crashes.
    unique_name = "constraint_baw_#{table}_unique"
    no_overlap_name = "constraint_baw_#{table}_non_overlapping"
    if add
      <<~SQL
        ALTER TABLE #{table} ADD CONSTRAINT #{no_overlap_name} EXCLUDE USING GIST (#{with} WITH =, #{column} WITH &&);
        ALTER TABLE #{table} ADD CONSTRAINT #{unique_name} UNIQUE (#{with}, #{column});
        ALTER TABLE #{table} SET UNLOGGED;
      SQL
    else
      <<~SQL
        ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{unique_name};
        ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{no_overlap_name};
        ALTER TABLE #{table} SET LOGGED;
      SQL
    end => query

    execute(query)
  end

  # No primary key is intentional, uniqueness enforced by constraints
  # Fill factor ensures some space is left in pages so updates can occur efficiently.
  def change
    # user statistics
    create_table(
      :user_statistics, id: false, options: 'WITH (fillfactor = 90)'
    ) do |t|
      # anonymous access is tracked with a nil user
      t.bigint :user_id, null: true
      t.tsrange :bucket, **STATS_BUCKET_OPTIONS

      t.bigint :audio_segment_download_count, default: 0
      t.bigint :audio_original_download_count, default: 0
      t.decimal :audio_download_duration, default: 0
    end

    add_index :user_statistics, :user_id
    add_foreign_key :user_statistics, :users

    # audio recording statistics
    create_table(
      :audio_recording_statistics, id: false, options: 'WITH (fillfactor = 90)'
    ) do |t|
      t.bigint :audio_recording_id, null: false
      t.tsrange :bucket, **STATS_BUCKET_OPTIONS

      t.bigint :original_download_count, default: 0
      t.bigint :segment_download_count, default: 0
      t.decimal :segment_download_duration, default: 0
    end

    add_index :audio_recording_statistics, :audio_recording_id
    add_foreign_key :audio_recording_statistics, :audio_recordings

    reversible do |change|
      change.up do
        # btree gist is needed to create a unique index across a scalar and a range
        execute 'CREATE EXTENSION IF NOT EXISTS btree_gist'
        alter_range_constraint(:user_statistics, :bucket, with: :user_id, add: true)
        alter_range_constraint(:audio_recording_statistics, :bucket, with: :audio_recording_id, add: true)
      end
      change.down do
        alter_range_constraint(:user_statistics, :bucket, with: :user_id, add: false)
        alter_range_constraint(:audio_recording_statistics, :bucket, with: :audio_recording_id, add: false)
      end
    end
  end
end
