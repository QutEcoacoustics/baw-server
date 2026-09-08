# frozen_string_literal: true

describe 'reports/tag_rate' do
  create_entire_hierarchy

  let(:creator) { writer_user }

  let(:body) { { options: { bucket_size: :day }, filter: {} } }

  let(:start_date) { Time.parse('2000-03-06 07:06:59Z').utc }
  let(:duration_seconds) { 3600 }

  let(:another_recording) {
    create(:audio_recording, creator:, site:, recorded_date: start_date + 1.day, duration_seconds:)
  }

  let(:bucket_size) { 1.day }
  let(:bucket_one_range_start) { audio_recording.recorded_date.utc.at_beginning_of_day }
  let(:bucket_two_range_start) { another_recording.recorded_date.utc.at_beginning_of_day }
  let(:expected_data) {
    [
      {
        site_id: site.id,
        tags: [
          {
            tag_id: tag.id,
            detected_manual_minutes: 2,
            detected_analysis_minutes: 2,
            detected_combined_minutes: 3
          }
        ],
        range: [bucket_one_range_start, bucket_one_range_start + bucket_size],
        analysis_ids: [analysis_job.id],
        total_minutes: 120,
        manual_events_minutes: 2,
        total_analysed_minutes: 60
      },
      {
        site_id: site.id,
        tags: [
          {
            tag_id: tag.id,
            detected_manual_minutes: 0,
            detected_analysis_minutes: 3,
            detected_combined_minutes: 3
          }
        ],
        range: [bucket_two_range_start, bucket_two_range_start + bucket_size],
        analysis_ids: [analysis_job.id],
        total_minutes: 60,
        manual_events_minutes: 0,
        total_analysed_minutes: 60
      }
    ]
  }

  before do
    audio_recording.update(recorded_date: start_date, duration_seconds:)
    analysis_jobs_item.update(result: AnalysisJobsItem::RESULT_SUCCESS)

    # Create a recording that will have no events and no analysis, directly after the first recording.
    create(:audio_recording, creator:, site:, recorded_date: start_date + duration_seconds, duration_seconds:)

    # The hierarchy audio_event is an 'analysis' based event; update its
    # start/end times, and create a second 'analysis' based event.
    audio_event.update(start_time_seconds: 600, end_time_seconds: 605)
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
      end_time_seconds: 1205, audio_event_import_file: audio_event_import_file)

    # Create two 'manual' based events; the first overlaps with the first 'analysis' based event.
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
      end_time_seconds: 605)
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1800,
      end_time_seconds: 1805)

    # Create three 'analysis' based events on `another_recording`
    second_analysis_job_item = create(:analysis_jobs_item, analysis_job:, result: AnalysisJobsItem::RESULT_SUCCESS,
      audio_recording: another_recording, script:)

    another_event_import_file = create(:audio_event_import_file, :with_path,
      analysis_jobs_item: second_analysis_job_item, audio_event_import:)

    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 300, end_time_seconds: 305, audio_event_import_file: another_event_import_file)
    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 1800, end_time_seconds: 1805, audio_event_import_file: another_event_import_file)
    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 2400, end_time_seconds: 2405, audio_event_import_file: another_event_import_file)

    # Create an audio_event that writer_user has no access to, to prove it is not included in the report.
    create(:audio_event_with_tags)
  end

  describe 'with bucket size of day' do
    it 'returns the correct detection counts and bucket summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end

    it 'returns any bucket that contains audio, even if there are no tags' do
      more_audio = create(:audio_recording, creator:, site:, recorded_date: start_date + 3.days, duration_seconds:)
      bucket_with_no_tags = { site_id: site.id,
                              range: [more_audio.recorded_date.utc.at_beginning_of_day,
                                      more_audio.recorded_date.utc.at_beginning_of_day + bucket_size],
                              tags: [],
                              analysis_ids: [],
                              total_minutes: 60,
                              manual_events_minutes: 0,
                              total_analysed_minutes: 0 }

      post '/reports/tag_rate', params: body, **api_headers(writer_token)

      expect_success
      expect(api_data).to match_array(expected_data + [bucket_with_no_tags])
    end

    context 'with filter by tag' do
      let(:body) do
        {
          options: { bucket_size: :day },
          filter: { 'tags.id': { in: [tag.id] } }
        }
      end

      let(:expected_data) {
        super().tap do |data|
          data.first[:total_minutes] = 60
        end
      }

      it 'returns rates only for recordings with the specified tag' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expect(api_data).to match expected_data
      end

      context 'when a recording also contains a tag that was not in the filter' do
        let!(:other_tag) { create(:tag, creator:) }

        before do
          create(:audio_event_using_tag, audio_recording:, creator:, tag: other_tag,
            start_time_seconds: 1900, end_time_seconds: 1905)
        end

        it 'returns a tag result for all tags on the recording, not just the filtered tag' do
          post '/reports/tag_rate', params: body, **api_headers(writer_token)
          expect_success

          bucket = expected_data.first
          bucket[:manual_events_minutes] += 1
          bucket[:tags] << {
            tag_id: other_tag.id,
            detected_manual_minutes: 1,
            detected_analysis_minutes: 0,
            detected_combined_minutes: 1
          }

          expect(api_data).to match(expected_data)
        end
      end
    end

    context 'with multiple tags per audio event' do
      let!(:new_tagging) {
        create(:tagging, tag: create(:tag, creator:), audio_event:)
      }

      it 'counts each tag once per detected minute' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expected_data.first[:tags] << {
          tag_id: new_tagging.tag.id,
          detected_manual_minutes: 0,
          detected_analysis_minutes: 1,
          detected_combined_minutes: 1
        }
        expect(api_data).to match expected_data
      end
    end

    context 'with repeated analysis and duplicate events' do
      let(:additional_analysis_job) {
        script = create(:script, creator:, provenance: create(:provenance, creator:))
        create(:analysis_job, project:, creator:, scripts: [script])
      }

      before do
        script = additional_analysis_job.scripts.first
        additional_analysis_job_item = create(:analysis_jobs_item, analysis_job: additional_analysis_job,
          script:, result: AnalysisJobsItem::RESULT_SUCCESS, audio_recording: audio_recording)
        additional_event_import = create(:audio_event_import, analysis_job: additional_analysis_job,
          creator:, updater: creator)
        additional_event_import_file = create(:audio_event_import_file, :with_path,
          audio_event_import: additional_event_import, analysis_jobs_item: additional_analysis_job_item)

        # Create two analysis based events that overlap completely with the two pre-existing analysis events.
        create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
          end_time_seconds: 605, audio_event_import_file: additional_event_import_file)
        create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
          end_time_seconds: 1205, audio_event_import_file: additional_event_import_file)
      end

      it 'returns distinct analysis jobs without double-counting detected minutes' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expected_data.first[:analysis_ids] = contain_exactly(
          analysis_job.id, additional_analysis_job.id
        )

        expect(api_data).to match expected_data
      end
    end

    context 'with multiple sites' do
      let(:another_site) { create(:site, creator:, region:, projects: [project]) }
      let!(:another_site_recording) {
        create(:audio_recording, creator:, site: another_site, recorded_date: start_date + 2.days,
          duration_seconds:)
      }

      before do
        create(:audio_event_using_tag, audio_recording: another_site_recording, creator:, tag:,
          start_time_seconds: 600, end_time_seconds: 605)
      end

      it 'emits results by bucket and site' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expect(api_data).to match_array(expected_data + [
          {
            site_id: another_site.id,
            tags: [
              {
                tag_id: tag.id,
                detected_manual_minutes: 1,
                detected_analysis_minutes: 0,
                detected_combined_minutes: 1
              }
            ],
            range: [another_site_recording.recorded_date.utc.at_beginning_of_day,
                    another_site_recording.recorded_date.utc.at_beginning_of_day + bucket_size],
            analysis_ids: [],
            total_minutes: 60,
            manual_events_minutes: 1,
            total_analysed_minutes: 0
          }
        ])
      end

      context 'with filters' do
        it 'excludes recordings from filtered sites' do
          params = body.merge(filter: { site_id: { not_eq: another_site.id } })
          post '/reports/tag_rate', params:, **api_headers(writer_token)
          expect_success

          expect(api_data).to match expected_data
        end
      end
    end
  end

  context 'with bucket size of week' do
    let(:body) { { options: { bucket_size: 'week' }, filter: {} } }
    let(:expected_data) do
      [
        {
          site_id: site.id,
          tags: [
            {
              tag_id: tag.id,
              detected_manual_minutes: 2,
              detected_analysis_minutes: 5,
              detected_combined_minutes: 6
            }
          ],
          range: [start_date.at_beginning_of_week(:monday),
                  start_date.at_beginning_of_week(:monday) + 1.week],
          analysis_ids: [analysis_job.id],
          total_minutes: 180,
          manual_events_minutes: 2,
          total_analysed_minutes: 120
        }
      ]
    end

    it 'returns the correct rates and recording summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success
      expect(api_data).to match expected_data
    end
  end

  context 'with bucket size of month' do
    let(:another_recording) {
      create(:audio_recording, creator:, site:, recorded_date: start_date + 2.months, duration_seconds:)
    }

    let(:bucket_size) { 1.month }
    let(:body) { { options: { bucket_size: 'month' }, filter: {} } }

    let(:bucket_one_range_start) { audio_recording.recorded_date.utc.at_beginning_of_month }
    let(:bucket_two_range_start) { (audio_recording.recorded_date.utc + 2.months).at_beginning_of_month }

    it 'returns the correct rates and recording summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end
  end

  context 'with bucket size of year' do
    let(:another_recording) {
      create(:audio_recording, creator:, site:, recorded_date: start_date + 1.year, duration_seconds:)
    }
    let(:bucket_size) { 1.year }
    let(:body) { { options: { bucket_size: 'year' }, filter: {} } }

    let(:bucket_one_range_start) { audio_recording.recorded_date.utc.at_beginning_of_year }
    let(:bucket_two_range_start) { (audio_recording.recorded_date.utc + 1.year).at_beginning_of_year }

    it 'returns the correct rates and recording summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end
  end

  it 'formats correctly as CSV' do
    post '/reports/tag_rate.csv', params: body, **api_headers(writer_token, accept: 'text/csv')

    expect_success
    expect(response.content_type).to include('text/csv')

    csv = CSV.parse(response.body, headers: true)
    headers = [:site_id, :range_lower, :range_upper, :tags, :analysis_ids, :total_minutes,
               :manual_events_minutes, :total_analysed_minutes]

    expect(csv.headers).to match_array(headers.map(&:to_s))
    expect(csv.first['site_id']).to eq(site.id.to_s)
  end
end
