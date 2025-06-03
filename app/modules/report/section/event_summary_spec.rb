# frozen_string_literal: true

describe 'Report::Section::EventSummary' do
  let(:params) do
    { options: { start_time: '2000-02-01T00:00:00Z',
                 end_time: '2000-07-02T00:00:00Z',
                 interval: '1 day' } }
  end
  let(:time_series_options) { Report::TimeSeries::Options.call(params) }
  let(:base_table) { AudioEvent.arel_table }
  let(:event_summary_options) { time_series_options.merge(base_table: base_table) }

  it 'generates the correct SQL for verification_base' do
    expected_sql = <<~SQL.squish
      SELECT
        "audio_events"."audio_event_id",
        "audio_events"."tag_id",
        "audio_events"."provenance_id",
        "audio_events"."score",
        "verifications"."id" AS "verification_id",
        "verifications"."confirmed"
      FROM "audio_events"
      LEFT OUTER JOIN "verifications" ON ("audio_events"."audio_event_id" = "verifications"."audio_event_id") AND ("audio_events"."tag_id" = "verifications"."tag_id")
    SQL
    sql = Report::Section::EventSummary.steps[0].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for verification_counts' do
    expected_sql = <<~SQL.squish
      SELECT
        "verification_base"."tag_id",
        "verification_base"."provenance_id",
        "verification_base"."audio_event_id",
        "verification_base"."score",
        "verification_base"."confirmed",
        COUNT("verification_base"."verification_id") AS "category_count",
        CAST(COALESCE(COUNT("verification_base"."verification_id"), 0) AS float) / NULLIF(COALESCE(SUM(COUNT("verification_base"."verification_id")) OVER (PARTITION BY "verification_base"."tag_id", "verification_base"."provenance_id", "verification_base"."audio_event_id"), 0), 0) AS "ratio"
      FROM "verification_base"
      GROUP BY
        "verification_base"."tag_id",
        "verification_base"."provenance_id",
        "verification_base"."audio_event_id",
        "verification_base"."confirmed",
        "verification_base"."score"
    SQL
    sql = Report::Section::EventSummary.steps[1].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for verification_counts_per_event' do
    expected_sql = <<~SQL.squish
      SELECT
        "verification_counts"."tag_id",
        "verification_counts"."provenance_id",
        "verification_counts"."audio_event_id",
        "verification_counts"."score",
        MAX("verification_counts"."ratio") AS "consensus_for_event",
        SUM("verification_counts"."category_count") AS "total_verifications_for_event"
      FROM "verification_counts"
      GROUP BY
        "verification_counts"."tag_id",
        "verification_counts"."provenance_id",
        "verification_counts"."audio_event_id",
        "verification_counts"."score"
    SQL
    sql = Report::Section::EventSummary.steps[2].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for verification_counts_per_tag_provenance' do
    expected_sql = <<~SQL.squish
      SELECT
        "verification_counts_per_tag_provenance_event"."tag_id",
        "verification_counts_per_tag_provenance_event"."provenance_id",
        COUNT("verification_counts_per_tag_provenance_event"."audio_event_id") AS "count",
        AVG("verification_counts_per_tag_provenance_event"."score") AS "score_mean",
        MIN("verification_counts_per_tag_provenance_event"."score") AS "score_min",
        MAX("verification_counts_per_tag_provenance_event"."score") AS "score_max",
        STDDEV_SAMP("verification_counts_per_tag_provenance_event"."score") AS "score_stdev",
        AVG("verification_counts_per_tag_provenance_event"."consensus_for_event") AS "consensus",
        SUM("verification_counts_per_tag_provenance_event"."total_verifications_for_event") AS "verifications"
      FROM "verification_counts_per_tag_provenance_event"
      GROUP BY
        "verification_counts_per_tag_provenance_event"."tag_id",
        "verification_counts_per_tag_provenance_event"."provenance_id"
    SQL
    sql = Report::Section::EventSummary.steps[3].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for score_bins' do
    expected_sql = <<~SQL.squish
      SELECT
        "audio_events"."tag_id",
        "audio_events"."provenance_id",
        width_bucket("audio_events"."score", "audio_events"."provenance_score_minimum", "audio_events"."provenance_score_maximum", 50) AS "bin_id",
        COUNT("audio_events"."audio_event_id") AS "bin_count",
        (COUNT("audio_events"."audio_event_id") OVER (PARTITION BY "audio_events"."tag_id", "audio_events"."provenance_id")) AS "group_count"
      FROM "audio_events"
      GROUP BY "audio_events"."tag_id", "audio_events"."provenance_id", "audio_events"."audio_event_id",
        width_bucket("audio_events"."score", "audio_events"."provenance_score_minimum", "audio_events"."provenance_score_maximum", 50)
    SQL
    sql = Report::Section::EventSummary.steps[4].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for score_bin_fractions' do
    expected_sql = <<~SQL.squish
      SELECT
        "score_bins"."tag_id",
        "score_bins"."provenance_id",
        "score_bins"."bin_id",
        "score_bins"."bin_count",
        "score_bins"."group_count",
        ROUND(CAST("score_bins"."bin_count" AS numeric) / NULLIF("score_bins"."group_count", 0), 3) AS "bin_fraction"
      FROM "score_bins"
    SQL
    sql = Report::Section::EventSummary.steps[5].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for bin_series' do
    expected_sql = <<~SQL.squish
      SELECT
        "distinct_tag_provenance"."tag_id",
        "distinct_tag_provenance"."provenance_id",
        bin_id
      FROM (SELECT DISTINCT
          "audio_events"."tag_id",
          "audio_events"."provenance_id"
        FROM "audio_events") "distinct_tag_provenance"
      CROSS JOIN generate_series(1, 50) AS "bin_id"
    SQL
    sql = Report::Section::EventSummary.steps[6].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for scores_all_bins' do
    expected_sql = <<~SQL.squish
      SELECT
        "bin_series"."tag_id",
        "bin_series"."provenance_id",
        array_agg(COALESCE("score_bin_fractions"."bin_fraction", 0)) AS "bin_fraction"
      FROM "bin_series"
      LEFT OUTER JOIN "score_bin_fractions" ON (
        "bin_series"."tag_id" = "score_bin_fractions"."tag_id"
      ) AND (
        "bin_series"."provenance_id" = "score_bin_fractions"."provenance_id"
      ) AND (
        "bin_series"."bin_id" = "score_bin_fractions"."bin_id"
      )
      GROUP BY
        "bin_series"."tag_id",
        "bin_series"."provenance_id"
    SQL
      .gsub!('( ', '(').gsub!(' )', ')')

    sql = Report::Section::EventSummary.steps[7].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for event_summaries' do
    expected_sql = <<~SQL.squish
      SELECT
        "verification_counts_per_tag_provenance"."provenance_id",
        "verification_counts_per_tag_provenance"."tag_id",
        jsonb_agg(jsonb_build_object(
          'count', "verification_counts_per_tag_provenance"."count",
          'verifications', "verification_counts_per_tag_provenance"."verifications",
          'consensus', "verification_counts_per_tag_provenance"."consensus"
        )) AS "events",
        jsonb_agg(jsonb_build_object(
          'bins', "scores_all_bins"."bin_fraction",
          'standard_deviation', ROUND("verification_counts_per_tag_provenance"."score_stdev", 3),
          'mean', ROUND("verification_counts_per_tag_provenance"."score_mean", 3),
          'min', "verification_counts_per_tag_provenance"."score_min",
          'max', "verification_counts_per_tag_provenance"."score_max"
        )) AS "score_histogram"
      FROM "verification_counts_per_tag_provenance"
      LEFT OUTER JOIN "scores_all_bins" ON (
        "verification_counts_per_tag_provenance"."tag_id" = "scores_all_bins"."tag_id"
      ) AND (
        "verification_counts_per_tag_provenance"."provenance_id" = "scores_all_bins"."provenance_id"
      )
      GROUP BY
        "verification_counts_per_tag_provenance"."tag_id",
        "verification_counts_per_tag_provenance"."provenance_id"
    SQL
      .gsub!('( ', '(').gsub!(' )', ')')

    sql = Report::Section::EventSummary.steps[8].call(event_summary_options).to_sql
    expect(sql).to eq(expected_sql)
  end
end
