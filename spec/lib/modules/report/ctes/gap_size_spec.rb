# frozen_string_literal: true

describe Report::Ctes::Coverage::GapSize do
  include SqlHelpers::Example
  subject { Report::Ctes::Coverage::GapSize.new(options: params) }

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
      result = Report::Ctes::Coverage::GapSize.new(options: parameters).execute
      expect(result[0]['gap_size']).to match(expected_results[index])
    end
  end
end

describe Report::Ctes::Coverage::CoverageEventsSortedSum do
  include SqlHelpers::Example
  subject { Report::Ctes::Coverage::CoverageEventsSortedSum.new(options: params) }

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
    expected_sql = <<~SQL.squish
      SELECT "coverage_events"."group_id", "coverage_events"."event_time",
              (SUM("coverage_events"."delta") OVER (PARTITION BY "coverage_events"."group_id" ORDER BY "coverage_events"."event_time", "coverage_events"."delta" DESC)) AS "running_sum"
      FROM "coverage_events"
    SQL
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

  it 'generates the correct #select_manager SQL' do
    expected_sql = <<~SQL.squish
      SELECT json_agg(jsonb_build_object('range', tsrange(CAST("final_coverage"."coverage_start" AS timestamp without time zone),
                                                          CAST("final_coverage"."coverage_end" AS timestamp without time zone), '[)'),
                                         'density',
                                          ROUND("final_coverage"."density", 3)))
      AS "coverage"
      FROM "final_coverage"
    SQL
    comparison_sql(actual, expected_sql)
  end

  it 'executes' do
    expect(subject.execute).to be_a(PG::Result)
  end
end
