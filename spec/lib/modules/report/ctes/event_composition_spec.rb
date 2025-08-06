# frozen_string_literal: true

describe 'Report Composition Ctes' do
  include SqlHelpers::Example

  let(:params) do
    { start_time: '2000-03-26 07:06:59',
      end_time: '2000-04-26 07:06:59',
      interval: '1 day' }
  end

  describe Report::Ctes::CompositionSeries do
    subject { Report::Ctes::CompositionSeries.new(options: params) }

    let(:actual) { subject.select_manager.to_sql }

    before do
      create(
        :audio_event_tagging,
        tag: create(:tag),
        confirmations: ['correct'],
        users: [create(:user)]
      )
    end

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT
          "bucket_time_series"."bucket_number",
          "bucket_time_series"."time_bucket" AS "range",
          distinct_tags.tag_id,
          COUNT(DISTINCT "base_table"."audio_event_id") AS "count",
          (SUM(COUNT(DISTINCT "base_table"."audio_event_id")) OVER (PARTITION BY "bucket_time_series"."bucket_number")) AS "total_tags_in_bin",
          COUNT("base_verification"."verification_id") AS "verifications",
          AVG("consensus_ratios"."consensus") AS "consensus"
        FROM "bucket_time_series"
        CROSS JOIN (
          SELECT DISTINCT tag_id FROM base_table
        ) distinct_tags
        LEFT OUTER JOIN "base_table" ON (
          "bucket_time_series"."time_bucket" @> "base_table"."start_time_absolute"
        ) AND (
          "base_table"."tag_id" = "distinct_tags"."tag_id"
        )
        LEFT OUTER JOIN "base_verification" ON (
          "base_table"."audio_event_id" = "base_verification"."audio_event_id"
        ) AND (
          "distinct_tags"."tag_id" = "base_verification"."tag_id"
        )
        LEFT OUTER JOIN (
          SELECT
            "subquery_one"."audio_event_id",
            "subquery_one"."tag_id",
            MAX("subquery_one"."ratio") AS "consensus"
          FROM (
            SELECT
              "base_verification"."audio_event_id",
              "base_verification"."tag_id",
              "base_verification"."confirmed",
              (CAST(COUNT("base_verification"."verification_id") AS float) /
                SUM(COUNT("base_verification"."verification_id")) OVER
                (PARTITION BY "base_verification"."audio_event_id", "base_verification"."tag_id"))
                AS "ratio"
            FROM "base_verification"
            WHERE "base_verification"."confirmed" IS NOT NULL
            GROUP BY
              "base_verification"."audio_event_id",
              "base_verification"."tag_id",
              "base_verification"."confirmed") "subquery_one"
          GROUP BY
            "subquery_one"."audio_event_id",
            "subquery_one"."tag_id") "consensus_ratios" ON ("consensus_ratios"."audio_event_id" = "base_table"."audio_event_id")
            AND ("consensus_ratios"."tag_id" = "distinct_tags"."tag_id")
        GROUP BY
          "bucket_time_series"."bucket_number",
          "bucket_time_series"."time_bucket",
          distinct_tags.tag_id
        ORDER BY
          distinct_tags.tag_id,
          "bucket_time_series"."bucket_number"
      SQL
      expected_sql.gsub!('( ', '(').gsub!(' )', ')')

      comparison_sql(actual, expected_sql)
    end

    it 'executes and returns a PG::Result' do
      expect(subject.execute).to be_a(PG::Result)
    end

    it 'summarised the correct number of Event/Tags' do
      expect(subject.execute.pluck('count').sum).to eq(Tagging.count)
    end
  end

  describe Report::Ctes::EventComposition do
    subject { Report::Ctes::EventComposition.new(options: params) }

    let(:params) do
      { start_time: '2000-03-26 07:06:59',
        end_time: '2000-04-26 07:06:59',
        interval: '1 day' }
    end

    let(:actual) { subject.select_manager.to_sql }

    before do
      create(:user) { |user|
        create(:audio_event_tagging, creator: user, tag: create(:tag), confirmations: ['correct'], users: [user])
      }
    end

    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT json_agg(c) FROM "composition_series" AS "c"
      SQL
      comparison_sql(subject.select_manager.to_sql, expected_sql)
    end

    it 'executes and returns a PG::Result' do
      expect(subject.execute).to be_a(PG::Result)
    end
  end
end
