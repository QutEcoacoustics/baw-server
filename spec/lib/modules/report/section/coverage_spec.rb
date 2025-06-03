# frozen_string_literal: true

describe 'Report::Section::Coverage' do
  let(:audio_recordings) { AudioRecording.arel_table }
  let(:time_series_options) { Report::TimeSeries::Options.call(parameters) }

  let(:params) {
    { options: { start_time: '2000-02-01T00:00:00Z',
                 end_time: '2000-07-02T00:00:00Z',
                 scaling_factor: 1920 } }
  }
  let(:time_series_options) { Report::TimeSeries::Options.call(params) }

  let(:coverage_options) {
    Report::Section::Coverage.options(**time_series_options) do |c|
      c[:source] = audio_recordings
      c[:lower_field] = audio_recordings[:recorded_date]
      c[:upper_field] = Report::ArelHelpers.arel_recorded_end_date(audio_recordings)
      c[:analysis_result] = false
      c[:project_field_as] = 'recording_coverage'
    end
  }
  let(:coverage) { Report::Section::Coverage.process(coverage_options) }

  it 'generates the correct SQL for gap size' do
    expected_sql = <<~SQL.squish
      SELECT
      make_interval(secs => (
        EXTRACT(EPOCH FROM upper("report_range"."range")) -
        EXTRACT(EPOCH FROM LOWER("report_range"."range"))) / 1920) AS "gap_size"
        FROM
        (SELECT
        tsrange(
          CAST('2000-02-01 00:00:00' AS timestamp without time zone),
          CAST('2000-07-02 00:00:00' AS timestamp without time zone), '[)') AS "range"
          ) "report_range"
    SQL
    expected_sql.gsub!('( ', '(').gsub!(' )', ')')

    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:gap_size][:select]

    expect(result.to_sql).to eq(expected_sql)
  end

  it 'calculates gap size for a given scaling factor and time range' do
    start_end_times = [['2025-01-01T00:00:00Z', '2025-01-02T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2025-01-08T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2026-01-01T00:00:00Z'],
                       ['2025-01-01T00:00:00Z', '2025-01-06T12:00:00Z'],
                       ['2000-02-01T00:00:00Z', '2000-07-02T00:00:00Z']]

    # expected postgres interval period of time (PT) results
    expected_results = ['PT45S', 'PT5M15S', 'PT4H33M45S', 'PT4M7.5S', 'PT1H54M']

    start_end_times.each_with_index do |(start_time, end_time), index|
      parameters = { options: { start_time: start_time, end_time: end_time, scaling_factor: 1920 } }
      time_series_options = Report::TimeSeries::Options.call(parameters)

      select = Report::Section::Coverage.calculate_gap_size(time_series_options)
      result = ActiveRecord::Base.connection.execute(select.to_sql)
      expect(result[0]['gap_size']).to match(expected_results[index])
    end
  end

  it 'generates the correct SQL for sort_with_lag' do
    expected_sql = <<~SQL.squish
      SELECT
        "audio_recordings"."recorded_date" AS "start_time",
        audio_recordings.recorded_date + CAST(audio_recordings.duration_seconds || ' seconds' as interval) AS "end_time",
        (LAG(audio_recordings.recorded_date + CAST(audio_recordings.duration_seconds || ' seconds' as interval)) OVER (ORDER BY "audio_recordings"."recorded_date")) AS "prev_end"
      FROM "audio_recordings"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:sort_with_lag][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for grouped' do
    expected_sql = <<~SQL.squish
      SELECT *,
        SUM(CASE WHEN start_time > prev_end + gap.gap_size THEN 1 ELSE 0 END) OVER (ORDER BY start_time) AS group_id
      FROM "sort_with_lag"
      CROSS JOIN gap_size as gap
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:grouped][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for coverage_intervals' do
    expected_sql = <<~SQL.squish
      SELECT
        "grouped"."group_id",
        MIN("grouped"."start_time") AS "coverage_start",
        MAX("grouped"."end_time") AS "coverage_end"
      FROM "grouped"
      GROUP BY "grouped"."group_id"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:coverage_intervals][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for coverage_events' do
    expected_sql = <<~SQL.squish
      ((SELECT "grouped"."group_id", "grouped"."start_time" AS "event_time", 1 AS "delta" FROM "grouped")
        UNION ALL
      (SELECT "grouped"."group_id", "grouped"."end_time" AS "event_time", -1 AS "delta" FROM "grouped"))
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:coverage_events][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for coverage_events_sorted_sum' do
    expected_sql = <<~SQL.squish
      SELECT
        "coverage_events"."group_id",
        "coverage_events"."event_time",
        (SUM("coverage_events"."delta") OVER (PARTITION BY "coverage_events"."group_id" ORDER BY "coverage_events"."event_time", "coverage_events"."delta" DESC)) AS "running_sum"
      FROM "coverage_events"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:coverage_events_sorted_sum][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for covered_intervals' do
    expected_sql = <<~SQL.squish
      SELECT
        "coverage_events_sorted_sum"."group_id",
        "coverage_events_sorted_sum"."event_time",
        (LEAD("coverage_events_sorted_sum"."event_time") OVER (PARTITION BY "coverage_events_sorted_sum"."group_id" ORDER BY "coverage_events_sorted_sum"."event_time")) AS "next_event_time",
        "coverage_events_sorted_sum"."running_sum"
      FROM "coverage_events_sorted_sum"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:covered_intervals][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for covered_durations' do
    expected_sql = <<~SQL.squish
      SELECT
        "covered_intervals"."group_id",
        SUM(EXTRACT(EPOCH FROM next_event_time - event_time)) AS "total_covered_seconds"
      FROM "covered_intervals"
      WHERE ("covered_intervals"."running_sum" > 0) AND ("covered_intervals"."next_event_time" IS NOT NULL)
      GROUP BY "covered_intervals"."group_id"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:covered_durations][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'generates the correct SQL for final_coverage' do
    expected_sql = <<~SQL.squish
      SELECT
        "coverage_intervals"."group_id",
        "coverage_intervals"."coverage_start",
        "coverage_intervals"."coverage_end",
        "covered_durations"."total_covered_seconds",
        EXTRACT(EPOCH FROM "coverage_intervals"."coverage_end" - "coverage_intervals"."coverage_start") AS "interval_seconds",
        ("covered_durations"."total_covered_seconds" / EXTRACT(EPOCH FROM "coverage_intervals"."coverage_end" - "coverage_intervals"."coverage_start")) AS "density"
      FROM "coverage_intervals"
      LEFT OUTER JOIN "covered_durations" ON "coverage_intervals"."group_id" = "covered_durations"."group_id"
      ORDER BY "coverage_intervals"."group_id"
    SQL
    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    result = coverage_collection[:final_coverage][:select]
    expect(result.to_sql).to eq(expected_sql)
  end

  it 'can be executed' do
    create(:audio_recording, recorded_date: '2000-02-01T00:00:00Z', duration_seconds: 60)

    coverage_collection = Report::Section::Coverage.process(options: coverage_options)
    collection = Report::Section.transform_to_collection(coverage_collection)
    ctes = collection.ctes

    select = Report::Section::Coverage.project(collection, coverage_options)
    out = ActiveRecord::Base.connection.execute(select.with(ctes).to_sql)
    expect(out.first).to eq(
      'recording_coverage' => '[{"range": "[\"2000-02-01 00:00:00\",\"2000-02-01 00:01:00\")", "density": 1.000}]'
    )
  end
end
