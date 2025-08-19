# frozen_string_literal: true

describe Report::Ctes::Coverage::IntervalGapSize do
  include SqlHelpers::Example
  subject { Report::Ctes::Coverage::IntervalGapSize.new(options: params) }

  let(:actual) { subject.select_manager.to_sql }
  let(:params) {
    {
      start_time: Time.new('2000-03-26T07:06:59').iso8601,
      end_time: Time.new('2000-04-26T07:06:59').iso8601,
      scaling_factor: 1920
    }
  }

  it 'generates the correct #select_manager SQL' do
    expected_sql = <<~SQL.squish
      SELECT make_interval(secs => (EXTRACT(EPOCH FROM upper("report_range"."range")) - EXTRACT(EPOCH FROM LOWER("report_range"."range"))) / 1920) AS "gap_size"
      FROM (SELECT tsrange(CAST('2000-03-26T07:06:59+00:00' AS timestamp without time zone), CAST('2000-04-26T07:06:59+00:00' AS timestamp without time zone), '[)') AS "range") "report_range"
    SQL

    comparison_sql(actual, expected_sql)
  end

  it 'calculates interval gap sizes correctly from a scaling factor' do
    start_end_times = [['2025-01-01T00:00:00Z', '2025-01-02T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2025-01-08T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2026-01-01T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2025-01-06T12:00:00Z'],
                       ['2000-02-01T00:00:00Z', '2000-07-02T00:00:00Z']]
    scaling_factor = 1920

    # expected postgres interval period of time (PT) results
    expected_results = ['PT45S', 'PT5M15S', 'PT4H33M45S', 'PT4M7.5S', 'PT1H54M']

    start_end_times.each_with_index do |(start_time, end_time), index|
      parameters = { start_time: start_time, end_time: end_time, scaling_factor: scaling_factor }
      result = Report::Ctes::Coverage::IntervalGapSize.new(options: parameters).execute
      expect(result[0]['gap_size']).to match(expected_results[index])
    end
  end
end

describe Report::Ctes::Coverage::TrackEventChanges do
  include SqlHelpers::Example
  subject { Report::Ctes::Coverage::TrackEventChanges.new(options: params) }

  let(:actual) { subject.select_manager.to_sql }
  let(:params) {
    {
      start_time: Time.new('2000-03-26T07:06:59').iso8601,
      end_time: Time.new('2000-04-26T07:06:59').iso8601,
      scaling_factor: 1920,
      lower_field: :recorded_date,
      upper_field: :end_date # see Report::Ctes::BaseEventReport
    }
  }

  before { create(:audio_event_with_tags) }

  it 'generates the correct #select_manager SQL' do
    debugger
    expected_sql = <<~SQL.squish
      SELECT "stacked_temporal_events"."group_id",
        "stacked_temporal_events"."event_time",
        (
          LEAD("stacked_temporal_events"."event_time") OVER (
            PARTITION BY "stacked_temporal_events"."group_id"
            ORDER BY "stacked_temporal_events"."event_time"
          )
        ) AS "next_event_time",
        (
          SUM("stacked_temporal_events"."delta") OVER (
            PARTITION BY "stacked_temporal_events"."group_id"
            ORDER BY "stacked_temporal_events"."event_time",
              "stacked_temporal_events"."delta" DESC
          )
        ) AS "running_sum"
      FROM "stacked_temporal_events"
    SQL
      .gsub(/\s+(\(|\)) (\(|\))/, '\1\2')
    comparison_sql(actual, expected_sql)
  end

  it 'executes' do
    expect(subject.execute).to be_a(PG::Result)
  end
end

describe Report::Ctes::Coverage::Coverage do
  include SqlHelpers::Example
  subject { Report::Ctes::Coverage::Coverage.new(options: params) }

  let(:actual) { subject.select_manager.to_sql }
  let(:params) {
    {
      start_time: Time.new('2000-03-26T07:06:59').iso8601,
      end_time: Time.new('2000-04-26T07:06:59').iso8601,
      scaling_factor: 1920,
      lower_field: :recorded_date,
      upper_field: :end_date
    }
  }

  before { create(:audio_event_with_tags) }

  context 'standard coverage report (without grouping by analysis)' do
    it 'generates the correct #select_manager SQL' do
      expected_sql = <<~SQL.squish
        SELECT json_agg(jsonb_build_object('range', tsrange(CAST("interval_density"."coverage_start" AS timestamp without time zone),
                                                            CAST("interval_density"."coverage_end" AS timestamp without time zone), '[)'),
                                           'density',
                                            ROUND("interval_density"."density", 3)))
        AS "coverage"
        FROM "interval_density"
      SQL
      comparison_sql(actual, expected_sql)
    end

    it 'executes' do
      expect(subject.execute).to be_a(PG::Result)
    end
  end

  context 'coverage report with grouping by analysis' do
    subject {
      Report::Ctes::Coverage::Coverage.new(suffix: 'analysis', options: params.merge({ analysis_result: true }))
    }

    let(:report) {
      Report::AudioEvents.new(options: params)
    }

    it 'executes' do
      debugger
      expect(subject.execute).to be_a(PG::Result)
    end
  end
end
