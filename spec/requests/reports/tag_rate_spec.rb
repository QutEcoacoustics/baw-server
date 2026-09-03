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

  before do
    audio_recording.update(recorded_date: start_date, duration_seconds:)
    analysis_jobs_item.update(result: AnalysisJobsItem::RESULT_SUCCESS)

    # Create a recording that will have no events and no analysis, directly after the first recording.
    create(:audio_recording, creator:, site:, recorded_date: start_date + duration_seconds, duration_seconds:)

    # Create two 'analysis' based events and two 'manual' events.
    audio_event.update(start_time_seconds: 600, end_time_seconds: 605)
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
      end_time_seconds: 1205, audio_event_import_file: audio_event_import_file)

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
    let(:bucket_size) { 1.day }

    let(:expected_data) {
      [
        {
          site_id: site.id,
          buckets: [
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 2,
                  detected_analysis_minutes: 2,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [audio_recording.recorded_date.utc.at_beginning_of_day,
                       audio_recording.recorded_date.utc.at_beginning_of_day + bucket_size],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 120,
              manual_events_minutes: 2,
              cumulative_analysed_minutes: 60
            },
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 0,
                  detected_analysis_minutes: 3,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [another_recording.recorded_date.utc.at_beginning_of_day,
                       another_recording.recorded_date.utc.at_beginning_of_day + bucket_size],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 60,
              manual_events_minutes: 0,
              cumulative_analysed_minutes: 60
            }
          ]
        }
      ]
    }

    it 'returns the correct rates and recording summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end

    context 'with filter by tag' do
      let(:body) do
        {
          options: { bucket_size: :day },
          filter: { 'tags.id': { in: [tag.id] } }
        }
      end

      it 'returns rates only for recordings with the specified tag' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expected_data.first[:buckets].first[:cumulative_minutes] = 60
        expect(api_data).to match expected_data
      end

      context 'when a recording also contains a tag that wasn\'t in the filter' do
        let!(:other_tag) { create(:tag, creator:) }

        before do
          create(:audio_event_using_tag, audio_recording:, creator:, tag: other_tag,
            start_time_seconds: 1900, end_time_seconds: 1905)
        end

        it 'returns rates for all tags, not just the filtered tag' do
          post '/reports/tag_rate', params: { options: { bucket_size: :day }, filter: {} }, **api_headers(writer_token)
          expect_success

          bucket = expected_data.first[:buckets].shift
          bucket[:manual_events_minutes] += 1
          bucket[:tags].push({
            tag_id: other_tag.id,
            detected_manual_minutes: 1,
            detected_analysis_minutes: 0,
            detected_combined_minutes: 1
          })

          expected_data.first[:buckets].unshift(bucket)

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

        expected_data.first[:buckets].first[:tags] << {
          tag_id: new_tagging.tag.id,
          detected_manual_minutes: 0,
          detected_analysis_minutes: 1,
          detected_combined_minutes: 1
        }
        expect(api_data).to match expected_data
      end
    end

    context 'with additional analysis and events' do
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

        create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
          end_time_seconds: 605, audio_event_import_file: additional_event_import_file)
        create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
          end_time_seconds: 1205, audio_event_import_file: additional_event_import_file)
      end

      it 'returns distinct analysis jobs without double-counting detected minutes' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expected_data.first[:buckets].first[:analysis_ids] = contain_exactly(
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

      it 'partitions rates by site' do
        post '/reports/tag_rate', params: body, **api_headers(writer_token)
        expect_success

        expect(api_data).to match_array(expected_data + [
          {
            site_id: another_site.id,
            buckets: [
              {
                tags: [
                  {
                    tag_id: tag.id,
                    detected_manual_minutes: 1,
                    detected_analysis_minutes: 0,
                    detected_combined_minutes: 1
                  }
                ],
                bucket: [another_site_recording.recorded_date.utc.at_beginning_of_day,
                         another_site_recording.recorded_date.utc.at_beginning_of_day + bucket_size],
                analysis_ids: [],
                cumulative_minutes: 60,
                manual_events_minutes: 1,
                cumulative_analysed_minutes: 0
              }
            ]
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
          buckets: [
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 2,
                  detected_analysis_minutes: 5,
                  detected_combined_minutes: 6
                }
              ],
              bucket: [start_date.at_beginning_of_week(:monday),
                       start_date.at_beginning_of_week(:monday) + 1.week],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 180,
              manual_events_minutes: 2,
              cumulative_analysed_minutes: 120
            }
          ]
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
    let(:body) { { options: { bucket_size: 'month' }, filter: {} } }
    let(:another_recording) {
      create(:audio_recording, creator:, site:, recorded_date: start_date + 2.months, duration_seconds:)
    }
    let(:expected_data) do
      [
        {
          site_id: site.id,
          buckets: [
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 2,
                  detected_analysis_minutes: 2,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [start_date.at_beginning_of_month,
                       start_date.at_beginning_of_month + 1.month],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 120,
              manual_events_minutes: 2,
              cumulative_analysed_minutes: 60
            },
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 0,
                  detected_analysis_minutes: 3,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [(start_date + 2.months).at_beginning_of_month,
                       (start_date + 2.months).at_beginning_of_month + 1.month],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 60,
              manual_events_minutes: 0,
              cumulative_analysed_minutes: 60
            }
          ]
        }
      ]
    end

    it 'returns the correct rates and recording summaries' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end
  end

  context 'with bucket size of year' do
    let(:body) { { options: { bucket_size: 'year' }, filter: {} } }
    let(:another_recording) {
      create(:audio_recording, creator:, site:, recorded_date: start_date + 1.year, duration_seconds:)
    }
    let(:expected_data) do
      [
        {
          site_id: site.id,
          buckets: [
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 2,
                  detected_analysis_minutes: 2,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [start_date.at_beginning_of_year,
                       start_date.at_beginning_of_year + 1.year],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 120,
              manual_events_minutes: 2,
              cumulative_analysed_minutes: 60
            },
            {
              tags: [
                {
                  tag_id: tag.id,
                  detected_manual_minutes: 0,
                  detected_analysis_minutes: 3,
                  detected_combined_minutes: 3
                }
              ],
              bucket: [(start_date + 1.year).at_beginning_of_year,
                       (start_date + 1.year).at_beginning_of_year + 1.year],
              analysis_ids: [analysis_job.id],
              cumulative_minutes: 60,
              manual_events_minutes: 0,
              cumulative_analysed_minutes: 60
            }
          ]
        }
      ]
    end

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
    expect(csv.headers).to eq(['site_id', 'buckets'])
    expect(csv.first['site_id']).to eq(site.id.to_s)
  end
end
