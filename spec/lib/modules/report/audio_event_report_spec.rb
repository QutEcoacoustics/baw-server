# frozen_string_literal: true

describe Report::AudioEventReport do
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
      expected_sql = <<~SQL.squish
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
            "sites"."id" AS "site_ids",
            "tags"."id" AS "tag_ids",
            "audio_events"."audio_recording_id" AS "audio_recording_ids",
            "audio_events"."provenance_id" AS "provenance_ids",
            "audio_events"."id" AS "audio_event_id",
            "audio_recordings"."recorded_date",
            audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || ' seconds' as interval) as start_time_absolute,
            audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || ' seconds' as interval) as end_time_absolute
          FROM "audio_events"
          INNER JOIN "taggings" ON "audio_events"."id" = "taggings"."audio_event_id"
          INNER JOIN "tags" ON "taggings"."tag_id" = "tags"."id"
          WHERE "audio_events"."deleted_at" IS NULL)
        SELECT ARRAY_AGG(DISTINCT site_ids),
          ARRAY_AGG(DISTINCT audio_recording_ids),
          ARRAY_AGG(DISTINCT tag_ids),
          ARRAY_AGG(DISTINCT provenance_ids)
        FROM "base_table"
      SQL
      query = report.build_query
      sql = query.to_sql

      expect(sql).to match(expected_sql)
    end
  end

  describe '#attributes' do
    it 'returns an array of Arel attributes' do
      attributes = report.attributes
      expect(attributes).to be_an(Array)
      expect(attributes.length).to eq(8)
    end
  end

  describe '#add_joins' do
    it 'adds joins to the query' do
      # Create an Arel::SelectManager to use as query
      query = Arel::SelectManager.new

      result = report.add_joins(query)
      sql = result.to_sql

      expect(sql).to include('JOIN "taggings"')
      expect(sql).to include('JOIN "tags"')
      expect(sql).to include('audio_event_id')
      expect(sql).to include('tag_id')
    end
  end
end
