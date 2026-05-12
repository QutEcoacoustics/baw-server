# frozen_string_literal: true

describe 'reports/analysis_coverage' do
  create_entire_hierarchy
  let(:start_date) { audio_recording.recorded_date.utc }
  let(:duration_seconds) { audio_recording.duration_seconds }
  let(:end_date) { start_date + 7.days }
  let(:gap_threshold) { (end_date - start_date) / 1920 }
  let(:gap_below_threshold) { 5.minutes }
  let(:gap_above_threshold) { 10.minutes }

  let(:expected_data) do
    cancelled_block_start = start_date + 1.day
    cancelled_block_end = cancelled_block_start + 20.minutes + 5.minutes
    cancelled_density = (3 * 5.minutes) / (cancelled_block_end - cancelled_block_start).seconds

    [{ site_id: site.id,
       result: AnalysisJobsItem::RESULT_SUCCESS,
       coverage: [start_date, start_date + duration_seconds],
       density: 1.0,
       gap_threshold: },

     { site_id: site.id,
       result: AnalysisJobsItem::RESULT_SUCCESS,
       coverage: [end_date - duration_seconds, end_date],
       density: 1.0,
       gap_threshold: },

     { site_id: site.id,
       result: AnalysisJobsItem::RESULT_CANCELLED,
       coverage: [cancelled_block_start, cancelled_block_end],
       gap_threshold:,
       density: cancelled_density }]
  end

  before do
    script = create(:script, creator: writer_user, provenance: create(:provenance, creator: writer_user))
    analysis_job = create(:analysis_job, project: project, creator: writer_user, scripts: [script])

    # Add an analysis job items to the original recording
    create(:analysis_jobs_item, analysis_job:, script:, result: AnalysisJobsItem::RESULT_SUCCESS, audio_recording:)

    # Create a cancelled block with a density of 3/5
    cancelled_block_start = start_date + 1.day
    [cancelled_block_start, cancelled_block_start + 10.minutes,
     cancelled_block_start + 20.minutes].each do |recorded_date|
      create(:audio_recording, creator: writer_user, site:, recorded_date:, duration_seconds: 5.minutes) { |rec|
        create(:analysis_jobs_item, analysis_job:, script:, result: AnalysisJobsItem::RESULT_CANCELLED, audio_recording: rec) #nolint
      }
    end

    # Make a recording that will act as the upper for the entire set of audio recordings;
    # ending exactly 1 week after the first audio_recording starts, resulting in a known gap threshold of 5 minutes 15 seconds
    (end_date - duration_seconds)
      .then { |recorded_date| create(:audio_recording, creator: writer_user, site:, recorded_date:, duration_seconds:) }
      .then { |rec| create(:analysis_jobs_item, analysis_job:, script:, result: AnalysisJobsItem::RESULT_SUCCESS, audio_recording: rec) }

    # Create a recording with no analysis job item, to prove it is not included in the coverage
    create(:audio_recording, creator: writer_user, site:, recorded_date: start_date, duration_seconds: 600_000)

    # Create a recording that writer_user has no access to, to prove it is not included in the coverage
    create(:audio_recording, recorded_date: start_date, duration_seconds: 600_000) { |rec|
      create(:analysis_jobs_item, analysis_job:, script:, result: AnalysisJobsItem::RESULT_SUCCESS,
        audio_recording: rec)
    }
  end

  it 'returns the correct coverage values, partitioned by analysis jobs item result' do
    post '/reports/analysis_coverage', params: { filter: {} }, **api_headers(writer_token)

    expect_success
    expect(api_data).to match_array(expected_data)
  end

  context 'with > 1 analysis job result on a recording' do
    before do
      analysis_job_2 = create(:analysis_job, project: project, creator: writer_user, scripts: [script])
      create(:analysis_jobs_item, analysis_job: analysis_job_2, script:, result: AnalysisJobsItem::RESULT_FAILED,
        audio_recording:)
    end

    it 'returns separate coverage entries for each analysis job result' do
      post '/reports/analysis_coverage', params: { filter: {} }, **api_headers(writer_token)

      expect_success
      expect(api_data).to match_array(expected_data + [
        { site_id: site.id,
          result: AnalysisJobsItem::RESULT_FAILED,
          coverage: [start_date, start_date + duration_seconds],
          density: 1.0,
          gap_threshold: }
      ])
    end
  end

  context 'with multiple sites' do
    let(:another_site) { create(:site, creator: writer_user, region: region, projects: [project]) }

    before do
      create(:audio_recording, creator: writer_user, site: another_site, recorded_date: start_date, duration_seconds:) {
        create(:analysis_jobs_item,
          analysis_job:, script:, result: AnalysisJobsItem::RESULT_SUCCESS, audio_recording: _1)
      }
    end

    it 'partitions by site and analysis jobs item result' do
      post '/reports/analysis_coverage', params: { filter: {} }, **api_headers(writer_token)

      expect_success
      expect(api_data).to match_array(expected_data + [
        { site_id: another_site.id,
          result: AnalysisJobsItem::RESULT_SUCCESS,
          coverage: [start_date, start_date + duration_seconds],
          density: 1.0,
          gap_threshold: }
      ])
    end

    context 'with filters' do
      it 'returns the correct coverage values, excluding filtered recordings' do
        filter = { filter: { site_id: { not_eq: another_site.id } } }
        post '/reports/analysis_coverage', params: filter, **api_headers(writer_token)

        expect_success
        expect(api_data).to match_array(expected_data)
      end
    end
  end
end
