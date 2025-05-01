# frozen_string_literal: true

describe Report::AudioEventReport do
  include SqlHelpers::Example

  let(:base_scope) { AudioEvent.all }
  let(:filter_params) {
    ActiveSupport::HashWithIndifferentAccess.new(
      { filter: {},
        options: {
          start_time: '2023-01-01',
          end_time: '2023-01-31',
          bucket_size: 'day'
        } }
    )
  }
  let(:report) { Report::AudioEventReport.new(filter_params, base_scope) }

  describe 'class structure' do
    it 'inherits from Report::Base' do
      expect(Report::AudioEventReport.superclass).to eq(Report::Base)
    end
  end

  describe '#build_query' do
    it 'generates a SQL query' do
      expected_sql = %{
        WITH "base_table" AS (SELECT
        "audio_events"."id",
        "audio_events"."audio_recording_id",
        "audio_events"."start_time_seconds",
        "audio_events"."end_time_seconds",
        "audio_events"."low_frequency_hertz",
        "audio_events"."high_frequency_hertz",
        "audio_events"."is_reference",
        "audio_events"."creator_id",
        "audio_events"."updated_at",
        "audio_events"."created_at",
        "audio_events"."audio_event_import_file_id",
        "audio_events"."import_file_index",
        "audio_events"."provenance_id",
        "audio_events"."channel",
        "audio_events_tags"."id" AS "tagging_ids",
        "sites"."id" AS "site_ids",
        "regions"."id" AS "region_ids",
        "tags"."id" AS "tag_id",
        "audio_events"."audio_recording_id" AS "audio_recording_ids",
        "audio_events"."provenance_id" AS "provenance_ids",
        "audio_events"."score" AS "score",
        "audio_events"."id" AS "audio_event_id",
        "audio_recordings"."recorded_date",
        audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || ' seconds' as interval) as start_time_absolute,
        audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || ' seconds' as interval) as end_time_absolute
        FROM "audio_events"
        INNER JOIN "audio_events_tags" ON "audio_events"."id" = "audio_events_tags"."audio_event_id"
        INNER JOIN "tags" ON "audio_events_tags"."tag_id" = "tags"."id"
        LEFT OUTER JOIN "regions" ON "regions"."id" = "sites"."region_id" WHERE "audio_events"."deleted_at" IS NULL),
        "time_range_and_interval" AS (
        SELECT tsrange(CAST('2023-01-01 00:00:00' AS timestamp without time zone), CAST('2023-01-31 00:00:00' AS timestamp without time zone), '[)') AS "time_range", INTERVAL '1 day' AS "bucket_interval"), "number_of_buckets" AS (
        SELECT "time_range_and_interval"."time_range", "time_range_and_interval"."bucket_interval", (SELECT (EXTRACT(EPOCH FROM upper("time_range_and_interval"."time_range")) - EXTRACT(EPOCH FROM LOWER("time_range_and_interval"."time_range"))) / EXTRACT(EPOCH FROM "time_range_and_interval"."bucket_interval") FROM "time_range_and_interval") "bucket_count" FROM "time_range_and_interval"
        ), "bucketed_time_series" AS (
        SELECT bucket_number, tsrange(lower(time_range) + ((bucket_number - 1) * bucket_interval), lower(time_range) + (bucket_number * bucket_interval)) AS "time_bucket" FROM "number_of_buckets" CROSS JOIN generate_series(1, CEIL("number_of_buckets"."bucket_count")) AS bucket_number),
        "data_with_allocated_bucket" AS (
        SELECT width_bucket(EXTRACT(EPOCH FROM "base_table"."start_time_absolute"), (SELECT EXTRACT(EPOCH FROM LOWER("number_of_buckets"."time_range")) FROM "number_of_buckets"), (SELECT EXTRACT(EPOCH FROM upper("number_of_buckets"."time_range")) FROM "number_of_buckets"), (SELECT CAST(CEIL("number_of_buckets"."bucket_count") AS int) FROM "number_of_buckets")) AS "bucket", "base_table"."tag_id", "base_table"."score" FROM "base_table"),
        "tag_first_appearance" AS (
        SELECT "data_with_allocated_bucket"."bucket", "data_with_allocated_bucket"."tag_id", "data_with_allocated_bucket"."score", CASE WHEN row_number() OVER (PARTITION BY "data_with_allocated_bucket"."tag_id" ORDER BY "data_with_allocated_bucket"."bucket") = 1 THEN 1 ELSE 0 END AS "is_first_time" FROM "data_with_allocated_bucket" WHERE "data_with_allocated_bucket"."bucket" IS NOT NULL
        ), "sum_groups" AS (
        SELECT SUM("tag_first_appearance"."is_first_time") AS "sum_new_tags", "tag_first_appearance"."bucket" FROM "tag_first_appearance" GROUP BY "tag_first_appearance"."bucket"
        ), "cumulative_unique_tag_series" AS (SELECT "bucketed_time_series"."bucket_number", "bucketed_time_series"."time_bucket" AS "range", CAST(COALESCE(SUM("sum_groups"."sum_new_tags") OVER (ORDER BY "bucketed_time_series"."bucket_number"), 0) AS int) AS "count" FROM "bucketed_time_series" LEFT OUTER JOIN "sum_groups" ON "bucketed_time_series"."bucket_number" = "sum_groups"."bucket"
        ), "verification_base" AS (
        SELECT "base_table"."audio_event_id", "base_table"."tag_id", "base_table"."provenance_id", "base_table"."score", "verifications"."id" AS "verification_id", "verifications"."confirmed" FROM "base_table" LEFT OUTER JOIN "verifications" ON ("base_table"."audio_event_id" = "verifications"."audio_event_id") AND ("base_table"."tag_id" = "verifications"."tag_id")),
        "verification_counts" AS (SELECT "verification_base"."tag_id", "verification_base"."provenance_id", "verification_base"."audio_event_id", "verification_base"."confirmed", COUNT("verification_base"."verification_id") AS "category_count", CAST(COALESCE(COUNT("verification_base"."verification_id"), 0) AS float) / NULLIF(COALESCE(SUM(COUNT("verification_base"."verification_id")) OVER (PARTITION BY "verification_base"."tag_id", "verification_base"."provenance_id", "verification_base"."audio_event_id"), 0), 0) AS "ratio" FROM "verification_base" GROUP BY "verification_base"."tag_id", "verification_base"."provenance_id", "verification_base"."audio_event_id", "verification_base"."confirmed"),
        "verification_counts_per_tag_provenance_event" AS (SELECT "verification_counts"."tag_id", "verification_counts"."provenance_id", "verification_counts"."audio_event_id", MAX("verification_counts"."ratio") AS "consensus_for_event", SUM("verification_counts"."category_count") AS "total_verifications_for_event" FROM "verification_counts" GROUP BY "verification_counts"."tag_id", "verification_counts"."provenance_id", "verification_counts"."audio_event_id"),
        "verification_counts_per_tag_provenance" AS (SELECT "verification_counts_per_tag_provenance_event"."tag_id", "verification_counts_per_tag_provenance_event"."provenance_id", COUNT("verification_counts_per_tag_provenance_event"."audio_event_id") AS "count", AVG("verification_counts_per_tag_provenance_event"."consensus_for_event") AS "consensus", SUM("verification_counts_per_tag_provenance_event"."total_verifications_for_event") AS "verifications" FROM "verification_counts_per_tag_provenance_event" GROUP BY "verification_counts_per_tag_provenance_event"."tag_id", "verification_counts_per_tag_provenance_event"."provenance_id"),
        "event_summaries" AS (SELECT "verification_counts_per_tag_provenance"."provenance_id", "verification_counts_per_tag_provenance"."tag_id", jsonb_agg(jsonb_build_object('count', "verification_counts_per_tag_provenance"."count", 'verifications', "verification_counts_per_tag_provenance"."verifications", 'consensus', "verification_counts_per_tag_provenance"."consensus")) AS "events" FROM "verification_counts_per_tag_provenance" GROUP BY "verification_counts_per_tag_provenance"."tag_id", "verification_counts_per_tag_provenance"."provenance_id") SELECT ARRAY_AGG(DISTINCT site_ids) AS "site_ids", ARRAY_AGG(DISTINCT region_ids) AS "region_ids", ARRAY_AGG(DISTINCT tag_id) AS "tag_ids", ARRAY_AGG(DISTINCT audio_recording_ids) AS "audio_recording_ids", ARRAY_AGG(DISTINCT provenance_id) AS "provenance_ids", COUNT(DISTINCT "base_table"."audio_event_id") AS "audio_events_count", (SELECT json_agg(row_to_json(t)) FROM "cumulative_unique_tag_series" AS "t") "accumulation_series", (SELECT json_agg(e) FROM "event_summaries" AS "e") "event_summaries" FROM "base_table"
      }
      expected_sql = expected_sql.squish
      query = report.build_query
      sql = query.to_sql
      comparison_sql(sql, expected_sql)
      # expect(sql.squish.strip).to eq(expected_sql.strip)
    end
  end

  describe '#attributes' do
    it 'returns an array of Arel attributes' do
      attributes = report.attributes
      expect(attributes).to be_an(Array)
      expect(attributes.length).to eq(11)
    end
  end

  describe '#add_joins' do
    it 'adds joins to the query' do
      # Create an Arel::SelectManager to use as query
      query = Arel::SelectManager.new

      result = report.add_joins(query)
      sql = result.to_sql

      expect(sql).to include('JOIN "audio_events_tags"')
      expect(sql).to include('JOIN "tags"')
      expect(sql).to include('audio_event_id')
      expect(sql).to include('tag_id')
    end
  end
end
