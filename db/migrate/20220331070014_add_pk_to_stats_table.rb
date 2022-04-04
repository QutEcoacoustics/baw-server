# frozen_string_literal: true

require_relative '20210730051645_create_recording_statistics'

# Adds a primary key to our statistics tables
# Previously on bad decisions: db/migrate/20210730051645_create_recording_statistics.rb
# It turns out using an exclusion constraint only meant an upsert never worked as intended...
# The exclusion constraint isn't checked when the upsert checks for conflicts,
# Which means postgres attempts to insert the row which fails when there actually is a conflict...
# Then the whole upsert fails and there was no point to any of this anyway.
# See https://github.com/QutEcoacoustics/baw-server/issues/534
# Also the lack of primary key means postgres' unique constraint failed on the nullable
# column and ended up just generating thousands of duplicate rows.
#
# So corrective actions:
# - add a separate table for anonymous user statistics
# - add primary keys to all tables
# - remove the EXCLUDE gist indexes. There is no way for them to work with upsert
#   and I value upsert semantics over non-overlapping buckets.
# - migrate the data for anonymous users to the new table
class AddPkToStatsTable < ActiveRecord::Migration[7.0]
  include BucketHelper

  def alter_pk_constraint(table, columns, add: true)
    name = "#{table}_pkey"
    cols = columns.join(', ')
    if add
      <<~SQL
        ALTER TABLE #{table} ADD CONSTRAINT #{name} PRIMARY KEY (#{cols});
      SQL
    else
      <<~SQL
        ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{name};
      SQL
    end => query

    execute(query)
  end

  # group all anonymous (null) rows, sum the stats and insert them in the new table.
  # then delete any rows with nulls in them from the old table
  def migrate_anonymous_user_statistics
    query = <<~SQL
      INSERT INTO
        anonymous_user_statistics (bucket, audio_segment_download_count, audio_original_download_count, audio_download_duration)
        SELECT
          bucket,
          SUM(audio_segment_download_count),
          SUM(audio_original_download_count),
          SUM(audio_download_duration)
        FROM user_statistics
        GROUP BY (bucket, user_id)
        HAVING user_id IS NULL;

      DELETE FROM user_statistics
      WHERE user_id IS NULL;
    SQL

    execute(query)
  end

  def change
    create_table(
      :anonymous_user_statistics,
      id: false,
      options: 'WITH (fillfactor = 90)',
      primary_key: :bucket
    ) do |t|
      t.tsrange :bucket, **STATS_BUCKET_OPTIONS
      t.bigint :audio_segment_download_count, default: 0
      t.bigint :audio_original_download_count, default: 0
      t.decimal :audio_download_duration, default: 0
    end

    reversible do |change|
      change.up do
        # add unique constraints to our new table
        alter_unique_constraint(:anonymous_user_statistics, :bucket, with: nil, add: true)

        # before we make the change to our table we have to transform it into a format that will be safe in the new schema!
        migrate_anonymous_user_statistics

        # finally, fix the old tables
        # including user_id in a primary key implicitly changes it tof NOT NULL,
        alter_pk_constraint(:user_statistics, [:user_id, :bucket], add: true)
        alter_pk_constraint(:audio_recording_statistics, [:audio_recording_id, :bucket], add: true)

        # and remove the exclude constraint
        alter_exclude_constraint(:user_statistics, :bucket, with: :user_id, add: false)
        alter_exclude_constraint(:audio_recording_statistics, :bucket, with: :audio_recording_id, add: false)
      end
      change.down do
        # we don't have a reverse migration defined for our data
        # the only reason we have this reversible is so we can unit test the forward migration
        # and the forward migration of data
        raise 'Not reversible' unless BawApp.dev_or_test?

        # in opposite order
        # and the exclude constraints
        alter_exclude_constraint(:user_statistics, :bucket, with: :user_id, add: true)
        alter_exclude_constraint(:audio_recording_statistics, :bucket,  with: :audio_recording_id, add: true)

        # remove the primary keys
        alter_pk_constraint(:user_statistics, [:user_id, :bucket], add: false)
        execute(
          <<~SQL
            ALTER TABLE "user_statistics" ALTER COLUMN "user_id" DROP NOT NULL;
          SQL
        )
        alter_pk_constraint(:audio_recording_statistics, [:audio_recording_id, :bucket], add: false)

        # for our new table, remove the unique constraint
        alter_unique_constraint(:anonymous_user_statistics, :bucket, with: nil, add: false)
      end
    end
  end
end
