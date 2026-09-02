# frozen_string_literal: true

describe 'reports/tag_rate' do
  create_entire_hierarchy

  let(:creator) { writer_user }

  let(:body) { { options: { bucket_size: :day }, filter: {} } }

  let(:start_date) { audio_recording.recorded_date.utc }
  let(:duration_seconds) { 3600 }

  let(:another_recording) {
    create(:audio_recording, creator:, site:, recorded_date: start_date + 1.day, duration_seconds:)
  }

  before do
    audio_recording.update(duration_seconds:)
    analysis_jobs_item.update(result: AnalysisJobsItem::RESULT_SUCCESS)

    # Create a recording that will have no events and no analysis.
    create(:audio_recording, creator:, site:, recorded_date: start_date + duration_seconds, duration_seconds:)

    # Create two 'analysis' based events and two 'manual' events.
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
      end_time_seconds: 605, audio_event_import_file: audio_event_import_file)
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
      end_time_seconds: 1205, audio_event_import_file: audio_event_import_file)

    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
      end_time_seconds: 605)
    create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1800,
      end_time_seconds: 1805)

    # Create three 'analysis' based events on `another_recording`
    second_analysis_job_item = create(:analysis_jobs_item, analysis_job:, result: AnalysisJobsItem::RESULT_SUCCESS,
      audio_recording: another_recording, script:)

    another_event_import_file = create(:audio_event_import_file, :with_path, analysis_jobs_item: second_analysis_job_item,
      audio_event_import:)

    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 300, end_time_seconds: 305, audio_event_import_file: another_event_import_file)
    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 1800, end_time_seconds: 1805, audio_event_import_file: another_event_import_file)
    create(:audio_event_using_tag, audio_recording: another_recording, creator:, tag: tag,
      start_time_seconds: 2400, end_time_seconds: 2405, audio_event_import_file: another_event_import_file)
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
                  detected_analysis_minutes: 3,
                  detected_combined_minutes: 4
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

    it 'passes' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected_data
    end
  end

  context 'with additional analysis and events' do
    before do
      script = create(:script, creator:, provenance: create(:provenance, creator:))
      analysis_job = create(:analysis_job, project:, creator:, scripts: [script])
      analysis_job_item = create(:analysis_jobs_item,
        analysis_job: analysis_job,
        script: script,
        result: AnalysisJobsItem::RESULT_SUCCESS,
        audio_recording: audio_recording)
      event_import = create(:audio_event_import, analysis_job: analysis_job, creator:, updater: creator)
      event_import_file = create(:audio_event_import_file, :with_path, audio_event_import: event_import,
        analysis_jobs_item: analysis_job_item)

      create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 600,
        end_time_seconds: 605, audio_event_import_file: event_import_file)
      create(:audio_event_using_tag, audio_recording:, creator:, tag:, start_time_seconds: 1200,
        end_time_seconds: 1205, audio_event_import_file: event_import_file)
    end
  end
end
