# frozen_string_literal: true

describe 'Report::Section::Composition' do
  let(:composition_options) do
    {
      bucketed_time_series: Report::Section::Accumulation::TABLE_BUCKETED_TIME_SERIES,
      base_table: AudioEvent.arel_table,
      base_verification: Report::Section::EventSummary::TABLE_VERIFICATION_BASE
    }
  end

  it 'generates the correct SQL for composition_series' do
    expected_sql = <<~SQL.squish
      SELECT
        "bucketed_time_series"."bucket_number",
        "bucketed_time_series"."time_bucket" AS "range",
        distinct_tags.tag_id,
        COUNT(DISTINCT "audio_events"."audio_event_id") AS "count",
        (SUM(COUNT(DISTINCT "audio_events"."audio_event_id")) OVER (PARTITION BY "bucketed_time_series"."bucket_number")) AS "total_tags_in_bin",
        COUNT("verification_base"."verification_id") AS "verifications",
        AVG("consensus_ratios"."consensus") AS "consensus"
      FROM "bucketed_time_series"
      CROSS JOIN (
        SELECT DISTINCT tag_id FROM base_table
      ) distinct_tags
      LEFT OUTER JOIN "audio_events" ON (
        "bucketed_time_series"."time_bucket" @> "audio_events"."start_time_absolute"
      ) AND (
        "audio_events"."tag_id" = "distinct_tags"."tag_id"
      )
      LEFT OUTER JOIN "verification_base" ON (
        "audio_events"."audio_event_id" = "verification_base"."audio_event_id"
      ) AND (
        "distinct_tags"."tag_id" = "verification_base"."tag_id"
      )
      LEFT OUTER JOIN (
        SELECT
          "subquery_one"."audio_event_id",
          "subquery_one"."tag_id",
          MAX("subquery_one"."ratio") AS "consensus"
        FROM (
          SELECT
            "verification_base"."audio_event_id",
            "verification_base"."tag_id",
            "verification_base"."confirmed",
            (CAST(COUNT("verification_base"."verification_id") AS float) /
              SUM(COUNT("verification_base"."verification_id")) OVER (
                PARTITION BY "verification_base"."audio_event_id", "verification_base"."tag_id"
              )
            ) AS "ratio"
          FROM "verification_base"
          WHERE "verification_base"."confirmed" IS NOT NULL
          GROUP BY
            "verification_base"."audio_event_id",
            "verification_base"."tag_id",
            "verification_base"."confirmed"
        ) "subquery_one"
        GROUP BY
          "subquery_one"."audio_event_id",
          "subquery_one"."tag_id"
      ) "consensus_ratios" ON (
        "consensus_ratios"."audio_event_id" = "audio_events"."audio_event_id"
      ) AND (
        "consensus_ratios"."tag_id" = "distinct_tags"."tag_id"
      )
      GROUP BY
        "bucketed_time_series"."bucket_number",
        "bucketed_time_series"."time_bucket",
        distinct_tags.tag_id
      ORDER BY
        distinct_tags.tag_id,
        "bucketed_time_series"."bucket_number"
    SQL
    expected_sql.gsub!('( ', '(').gsub!(' )', ')')

    composition_collection = Report::Section::Composition.process(options: composition_options)
    result = composition_collection[:composition_series][:select]
    expect(result.to_sql).to eq(expected_sql)
  end
end
