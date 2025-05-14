# frozen_string_literal: true

describe Report::TimeSeries::Coverage do
  audio_recordings = AudioRecording.arel_table

  describe 'CalculateGapSize' do
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
        time_series_options = Report::TimeSeries::StartEndTime.call(parameters)

        table, cte = subject.calculate_gap_size(time_series_options)
        result = ActiveRecord::Base.connection.execute(table.with(cte).project(Arel.star).to_sql)
        expect(result[0]['gap_size']).to match(expected_results[index])
      end
    end
  end

  describe 'arel_recorded_end_date' do
    it 'returns the correct recording end date from duration' do
      create(:audio_recording, recorded_date: '2025-01-01T00:00:00Z', duration_seconds: 3600)

      query = Arel::SelectManager.new.project(
        audio_recordings[:recorded_date],
        subject.arel_recorded_end_date.as('recorded_end_date')
      ).from(audio_recordings)

      result = ActiveRecord::Base.connection.execute(query.to_sql)
      expect(result[0]['recorded_end_date']).to eq('2025-01-01 01:00:00')
    end
  end

  describe 'VariableWidth' do
    before do
      create(:user) { |user|
        create(:project, creator: user) { |project|
          create(:region, project:, creator: user) { |region|
            create(:site, region:, projects: [project], creator: user) { |site|
              # recordings created out of order intentionally to test sorting;
              # group 1 = 3 recordings, 4 hours of group coverage, 3 hours of 'actual' coverage
              create(:audio_recording, recorded_date: '2000-04-03T00:00:00Z', duration_seconds: 3600, site:,
                creator: user)
              create(:audio_recording, recorded_date: '2000-04-03T02:00:00Z', duration_seconds: 3600, site:,
                creator: user)
              create(:audio_recording, recorded_date: '2000-04-03T03:00:00Z', duration_seconds: 3600, site:,
                creator: user)
              # group 0 = 1 recording, 1 hour of group coverage and 'actual' coverage
              create(:audio_recording, recorded_date: '2000-02-05T00:00:00Z', duration_seconds: 3600, site:,
                creator: user)
              # group 2 = 2 recordings, overlapping recordings; 1 hour 30 minutes of group and 'actual' coverage
              create(:audio_recording, recorded_date: '2000-06-01T00:00:00Z', duration_seconds: 3600, site:,
                creator: user)
              create(:audio_recording, recorded_date: '2000-06-01T00:30:00Z', duration_seconds: 3600, site:,
                creator: user)
            }
          }
        }
      }
    end

    let(:recordings) { AudioRecording.all }
    # 152 day range gives a gap size of 1 hour 54 minutes
    let(:start_time) { '2000-02-01T00:00:00Z' }
    let(:end_time) { '2000-07-02T00:00:00Z' }
    let(:scaling_factor) { 1920 }

    let(:parameters) { { options: { start_time: start_time, end_time: end_time, scaling_factor: scaling_factor } } }
    let(:time_series_options) { Report::TimeSeries::StartEndTime.call(parameters) }
    let(:coverage_options) do
      subject.coverage_options(
        source: audio_recordings,
        fields: { lower_field: audio_recordings[:recorded_date], upper_field: subject.arel_recorded_end_date }
      )
    end
    let(:coverage_cte_collection) { subject.coverage_series(time_series_options, coverage_options) }

    let(:expected_groups) { [0, 1, 1, 1, 2, 2] }

    it 'creates a valid options hash' do
      recording_start_date = audio_recordings[:recorded_date]
      recording_end_date = subject.arel_recorded_end_date

      options = subject.coverage_options(
        source: audio_recordings,
        fields: { lower_field: recording_start_date, upper_field: recording_end_date }
      )

      expect(options).to include(
        source: audio_recordings,
        fields: { lower_field: recording_start_date, upper_field: subject.arel_recorded_end_date }
      )
    end

    it 'sort_with_lag CTE is correctly sorted and includes prev_end' do
      result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:sort_with_lag).to_sql)
      result_times = result.to_a.map { |value|
        [value['start_time'], value['end_time']]
      }

      expected_sorted_times = recordings.map { |value|
        ended_at = value[:recorded_date] + value[:duration_seconds]
        [value[:recorded_date].utc, ended_at.utc]
      }.sort

      expect(result_times).to match_array(expected_sorted_times)

      result.to_a.each_cons(2) do |first, second|
        expect(second['prev_end']).to eq(first['end_time'])
      end
    end

    it 'grouped CTE correctly assigns group_ids' do
      result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:grouped).to_sql)
      expect(result.to_a.pluck('group_id')).to match_array(expected_groups)
    end

    it 'coverage_intervals CTE has one entry per group' do
      result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:coverage_intervals).to_sql)
      expect(result.to_a.length).to eq(expected_groups.uniq.length)
    end

    it 'coverage_events CTE has two events per original recording' do
      result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:coverage_events).to_sql)
      expect(result.to_a.length).to eq(recordings.length * 2)
    end

    it 'coverage_events_sorted_sum CTE executes without error' do
      # Basic check to ensure the CTE executes. More specific assertions can be added if needed.
      expect {
        ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:coverage_events_sorted_sum).to_sql)
      }.not_to raise_error
    end

    it 'covered_intervals CTE executes without error' do
      # Basic check to ensure the CTE executes.
      expect {
        ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:covered_intervals).to_sql)
      }.not_to raise_error
    end

    it 'covered_durations CTE executes without error' do
      # Basic check to ensure the CTE executes.
      expect {
        ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:covered_durations).to_sql)
      }.not_to raise_error
    end

    it 'final_coverage CTE calculates correct densities' do
      result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:final_coverage).to_sql)
      expected_densities = [1.0, 1.0, 0.75]
      expect(result.to_a.map { |r| r['density'].to_f }).to match_array(expected_densities)
    end

    it 'returns a series of coverage objects with range and density values in final JSON' do
      coverage_json_arel = subject.coverage_series_arel(coverage_cte_collection, 'coverage')
      with_expression_ctes = coverage_cte_collection.slice_with_dependencies(:final_coverage).ctes
      json_data_for_final_check = ActiveRecord::Base.connection.execute(coverage_json_arel.with(with_expression_ctes).to_sql)

      result_parsed = JSON.parse(json_data_for_final_check.first['coverage'])
      expect(result_parsed).to all match('range' => a_kind_of(String), 'density' => a_kind_of(Float))
    end
  end
end

describe Report::TimeSeries::Coverage do
  before do
    recordings = []
    create(:user) do |user|
      create(:project, creator: user) { |project|
        create(:region, project:, creator: user) { |region|
          create(:site, region:, projects: [project], creator: user) { |site|
            recordings = [
              # recordings created out of order intentionally to test sorting;
              # group 1 = 3 recordings, 4 hours of group coverage, 3 hours of 'actual' coverage
              create(:audio_recording, recorded_date: '2000-04-03T00:00:00Z', duration_seconds: 3600, site:,
                creator: user),
              create(:audio_recording, recorded_date: '2000-04-03T02:00:00Z', duration_seconds: 3600, site:,
                creator: user),
              create(:audio_recording, recorded_date: '2000-04-03T03:00:00Z', duration_seconds: 3600, site:,
                creator: user),
              # group 0 = 1 recording, 1 hour of group coverage and 'actual' coverage
              create(:audio_recording, recorded_date: '2000-02-05T00:00:00Z', duration_seconds: 3600, site:,
                creator: user),
              # group 2 = 2 recordings, overlapping recordings; 1 hour 30 minutes of group and 'actual' coverage
              create(:audio_recording, recorded_date: '2000-06-01T00:00:00Z', duration_seconds: 3600, site:,
                creator: user),
              create(:audio_recording, recorded_date: '2000-06-01T00:30:00Z', duration_seconds: 3600, site:,
                creator: user)
            ]
          }
        }
      }
    end
    # set up analysis_job and analysis_job_items with different status values
    # RESULT_SUCCESS = 'success'
    # RESULT_FAILED = 'failed'
    # RESULT_KILLED = 'killed'
    # RESULT_CANCELLED = 'cancelled'

    script = create(:script)
    job = create(:analysis_job)
    status_yielder = AnalysisJobsItem::ALLOWED_RESULTS.cycle
    # for each recording create an analysis job item with a different status
    AnalysisJobsItem.aasm.state_machine.config.toggle(:no_direct_assignment) do
      recordings.each do |recording|
        create(:analysis_jobs_item, analysis_job: job, script: script, result: status_yielder.next,
          audio_recording: recording)
      end
    end
  end

  let(:audio_recordings) { AudioRecording.arel_table }
  let(:recordings) { AudioRecording.all }
  let(:start_time) { '2000-02-01T00:00:00Z' }
  let(:end_time) { '2000-07-02T00:00:00Z' }
  let(:scaling_factor) { 1920 }

  let(:parameters) { { options: { start_time: start_time, end_time: end_time, scaling_factor: scaling_factor } } }
  let(:time_series_options) { Report::TimeSeries::StartEndTime.call(parameters) }
  let(:coverage_options) do
    subject.coverage_options(
      source: audio_recordings,
      fields: { lower_field: audio_recordings[:recorded_date], upper_field: subject.arel_recorded_end_date }
    )
  end

  let(:coverage_cte_collection) { subject.coverage_series(time_series_options, coverage_options) }

  it 'returns the correct analysis status' do
    result = ActiveRecord::Base.connection.execute(coverage_cte_collection.select(:final_coverage).to_sql)
    debugger
  end
end

# TODO: remove
# Helper method to execute a report query and return the result
# @param [Report::ArelHelpers::ReportQuery] query object
def execute_query(queries)
  with_queries = queries.map(&:cte)
  from_tables = queries.last.table

  select = Arel::SelectManager.new
    .with(with_queries)
    .project(Arel.star)
    .from(from_tables)
  ActiveRecord::Base.connection.execute(select.to_sql)
end
