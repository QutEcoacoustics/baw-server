# frozen_string_literal: true

describe 'Event Summary CTEs' do
  include SqlHelpers::Example

  before do
    user = create(:user)
    create(:audio_event_tagging, creator: user, tag: create(:tag), confirmations: ['correct'], users: [user])
  end

  let(:actual) { subject.select_manager.to_sql }
  let(:result) { subject.execute }

  describe Report::Ctes::EventSummary::VerificationCount do
    subject { Report::Ctes::EventSummary::VerificationCount.new }

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT
          "base_verification"."tag_id",
          "base_verification"."provenance_id",
          "base_verification"."audio_event_id",
          "base_verification"."score",
          "base_verification"."confirmed",
          COUNT("base_verification"."verification_id") AS "category_count",
          CAST(COALESCE(COUNT("base_verification"."verification_id"), 0) AS float) / NULLIF(COALESCE(SUM(COUNT("base_verification"."verification_id")) OVER (PARTITION BY "base_verification"."tag_id", "base_verification"."provenance_id", "base_verification"."audio_event_id"), 0), 0) AS "ratio"
        FROM "base_verification"
        GROUP BY
          "base_verification"."tag_id",
          "base_verification"."provenance_id",
          "base_verification"."audio_event_id",
          "base_verification"."confirmed",
          "base_verification"."score"
      SQL

      comparison_sql(actual, expected_sql)
    end

    it 'executes' do
      expect(result).to be_a(PG::Result)
      expect(result.first).to include('category_count' => 1, 'ratio' => 1.0)
    end
  end

  describe Report::Ctes::EventSummary::VerificationConsensus do
    subject { Report::Ctes::EventSummary::VerificationConsensus.new }

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT
          "verification_count"."tag_id",
          "verification_count"."provenance_id",
          "verification_count"."audio_event_id",
          "verification_count"."score",
          MAX("verification_count"."ratio") AS "consensus_for_event",
          SUM("verification_count"."category_count") AS "total_verifications_for_event"
        FROM "verification_count"
        GROUP BY
          "verification_count"."tag_id",
          "verification_count"."provenance_id",
          "verification_count"."audio_event_id",
          "verification_count"."score"
      SQL
      comparison_sql(actual, expected_sql)
    end

    it 'executes' do
      expect(result).to be_a(PG::Result)
    end
  end

  describe Report::Ctes::EventSummary::EventSummaryStatistics do
    subject { Report::Ctes::EventSummary::EventSummaryStatistics.new }

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT
          "verification_consensus"."tag_id",
          "verification_consensus"."provenance_id",
          COUNT("verification_consensus"."audio_event_id") AS "count",
          AVG("verification_consensus"."score") AS "score_mean",
          MIN("verification_consensus"."score") AS "score_min",
          MAX("verification_consensus"."score") AS "score_max",
          STDDEV_SAMP("verification_consensus"."score") AS "score_stdev",
          AVG("verification_consensus"."consensus_for_event") AS "consensus",
          SUM("verification_consensus"."total_verifications_for_event") AS "verifications"
        FROM "verification_consensus"
        GROUP BY
          "verification_consensus"."tag_id",
          "verification_consensus"."provenance_id"
      SQL

      comparison_sql(actual, expected_sql)
    end

    it 'executes' do
      expect(result).to be_a(PG::Result)
      expect(result.fields).to include('score_mean', 'score_min', 'score_max', 'score_stdev')
    end
  end

  describe Report::Ctes::EventSummary::ScoreHistogram do
    subject { Report::Ctes::EventSummary::ScoreHistogram.new }

    it 'executes' do
      expect(result).to be_a(PG::Result)
    end
  end

  describe Report::Ctes::EventSummary::EventSummaryAggregate do
    subject { Report::Ctes::EventSummary::EventSummaryAggregate.new }

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT json_agg(e) FROM "event_summary" AS "e"
      SQL

      comparison_sql(actual, expected_sql)
    end

    it 'generates the correct full SQL' do
      expected_sql = <<~SQL.squish
        WITH "base_table" AS (
          SELECT "audio_events"."id" AS "audio_event_id", "tag_id", "audio_events"."score", "audio_events"."provenance_id",
                 "recorded_date", "duration_seconds",
                 audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || ' seconds' as interval) as start_time_absolute,
                 ("audio_recordings"."recorded_date" + CAST("audio_recordings"."duration_seconds" || ' seconds' as interval)) AS "end_date",
                 "provenances"."score_minimum" AS "provenance_score_minimum", "provenances"."score_maximum" AS "provenance_score_maximum"
          FROM "audio_events"
          INNER JOIN "audio_recordings" ON ("audio_recordings"."deleted_at" IS NULL) AND ("audio_recordings"."id" = "audio_events"."audio_recording_id")
          INNER JOIN "audio_events_tags" ON "audio_events_tags"."audio_event_id" = "audio_events"."id"
          LEFT OUTER JOIN "provenances" ON ("provenances"."deleted_at" IS NULL) AND ("provenances"."id" = "audio_events"."provenance_id")
          WHERE "audio_events"."deleted_at" IS NULL
        ), "base_verification" AS (
          SELECT "base_table"."audio_event_id", "base_table"."tag_id", "base_table"."provenance_id", "base_table"."score",
                 "verifications"."id" AS "verification_id", "verifications"."confirmed"
          FROM "base_table"
          LEFT OUTER JOIN "verifications" ON ("base_table"."audio_event_id" = "verifications"."audio_event_id") AND ("base_table"."tag_id" = "verifications"."tag_id")
        ), "verification_count" AS (
          SELECT "base_verification"."tag_id", "base_verification"."provenance_id", "base_verification"."audio_event_id",
                 "base_verification"."score", "base_verification"."confirmed", COUNT("base_verification"."verification_id") AS "category_count",
                 CAST(COALESCE(COUNT("base_verification"."verification_id"), 0) AS float) /
                 NULLIF(COALESCE(SUM(COUNT("base_verification"."verification_id")) OVER (PARTITION BY "base_verification"."tag_id",
                 "base_verification"."provenance_id", "base_verification"."audio_event_id"), 0), 0) AS "ratio"
          FROM "base_verification"
          GROUP BY "base_verification"."tag_id", "base_verification"."provenance_id", "base_verification"."audio_event_id",
                   "base_verification"."confirmed", "base_verification"."score"
        ), "verification_consensus" AS (
          SELECT "verification_count"."tag_id", "verification_count"."provenance_id", "verification_count"."audio_event_id",
                 "verification_count"."score", MAX("verification_count"."ratio") AS "consensus_for_event",
                 SUM("verification_count"."category_count") AS "total_verifications_for_event"
          FROM "verification_count"
          GROUP BY "verification_count"."tag_id", "verification_count"."provenance_id", "verification_count"."audio_event_id",
                   "verification_count"."score"
        ), "event_summary_statistics" AS (
          SELECT "verification_consensus"."tag_id", "verification_consensus"."provenance_id",
                 COUNT("verification_consensus"."audio_event_id") AS "count", AVG("verification_consensus"."score") AS "score_mean",
                 MIN("verification_consensus"."score") AS "score_min", MAX("verification_consensus"."score") AS "score_max",
                 STDDEV_SAMP("verification_consensus"."score") AS "score_stdev",
                 AVG("verification_consensus"."consensus_for_event") AS "consensus",
                 SUM("verification_consensus"."total_verifications_for_event") AS "verifications"
          FROM "verification_consensus"
          GROUP BY "verification_consensus"."tag_id", "verification_consensus"."provenance_id"
        ), "bin_series" AS (
          SELECT "distinct_tag_provenance"."tag_id", "distinct_tag_provenance"."provenance_id", bin_id
          FROM (SELECT DISTINCT "base_table"."tag_id", "base_table"."provenance_id" FROM "base_table") "distinct_tag_provenance"
          CROSS JOIN generate_series(1, 50) AS "bin_id"
        ), "score_histogram" AS (
          SELECT "base_table"."tag_id", "base_table"."provenance_id",
                 width_bucket("base_table"."score", "base_table"."provenance_score_minimum", "base_table"."provenance_score_maximum", 50) AS "bin_id",
                 COUNT("base_table"."audio_event_id") AS "bin_count",
                 (COUNT("base_table"."audio_event_id") OVER (PARTITION BY "base_table"."tag_id", "base_table"."provenance_id")) AS "group_count"
          FROM "base_table"
          GROUP BY "base_table"."tag_id", "base_table"."provenance_id", "base_table"."audio_event_id",
                   width_bucket("base_table"."score", "base_table"."provenance_score_minimum", "base_table"."provenance_score_maximum", 50)
        ), "score_bin_fractions" AS (
          SELECT "score_histogram"."tag_id", "score_histogram"."provenance_id", "score_histogram"."bin_id",
                 "score_histogram"."bin_count", "score_histogram"."group_count",
                 ROUND(CAST("score_histogram"."bin_count" AS numeric) / NULLIF("score_histogram"."group_count", 0), 3) AS "bin_fraction"
          FROM "score_histogram"
        ), "bin_series_scores" AS (
          SELECT "bin_series"."tag_id", "bin_series"."provenance_id",
                 array_agg(COALESCE("score_bin_fractions"."bin_fraction", 0)) AS "bin_fraction"
          FROM "bin_series"
          LEFT OUTER JOIN "score_bin_fractions" ON ("bin_series"."tag_id" = "score_bin_fractions"."tag_id") AND
                 ("bin_series"."provenance_id" = "score_bin_fractions"."provenance_id") AND ("bin_series"."bin_id" = "score_bin_fractions"."bin_id")
          GROUP BY "bin_series"."tag_id", "bin_series"."provenance_id"
        ), "event_summary" AS (
          SELECT "event_summary_statistics"."provenance_id", "event_summary_statistics"."tag_id",
                 jsonb_agg(jsonb_build_object('count', "event_summary_statistics"."count",
                                              'verifications', "event_summary_statistics"."verifications",
                                              'consensus', "event_summary_statistics"."consensus")) AS "events",
                 jsonb_agg(jsonb_build_object('bins', "bin_series_scores"."bin_fraction",
                                              'standard_deviation', ROUND("event_summary_statistics"."score_stdev", 3),
                                              'mean', ROUND("event_summary_statistics"."score_mean", 3),
                                              'min', "event_summary_statistics"."score_min",
                                              'max', "event_summary_statistics"."score_max")) AS "score_histogram"
          FROM "event_summary_statistics"
          LEFT OUTER JOIN "bin_series_scores" ON ("event_summary_statistics"."tag_id" = "bin_series_scores"."tag_id") AND
                 ("event_summary_statistics"."provenance_id" = "bin_series_scores"."provenance_id")
          GROUP BY "event_summary_statistics"."tag_id", "event_summary_statistics"."provenance_id"
        )
        SELECT json_agg(e) FROM "event_summary" AS "e"
      SQL
        .gsub!('( ', '(').gsub!(' )', ')')

      comparison_sql(subject.to_sql, expected_sql)
    end

    it 'executes' do
      expect(result).to be_a(PG::Result)
    end
  end
end
