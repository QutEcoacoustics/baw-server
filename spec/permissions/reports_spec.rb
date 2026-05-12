# frozen_string_literal: true

describe 'Reports permissions' do
  create_entire_hierarchy
  before do
    script = create(:script, creator: writer_user, provenance: create(:provenance, creator: writer_user))
    analysis_job = create(:analysis_job, project: project, creator: writer_user, scripts: [script])

    # Add an analysis job items to the original recording
    create(:analysis_jobs_item, analysis_job:, script:, result: AnalysisJobsItem::RESULT_SUCCESS, audio_recording:)
  end

  given_the_route '/reports' do
    {
      id: :invalid
    }
  end

  send_create_body do
    [{}, :json]
  end

  send_update_body do
    [{}, :json]
  end

  let(:day) { audio_recording.recorded_date.utc.at_beginning_of_day }

  with_custom_action(:recording_coverage, path: 'recording_coverage', verb: :post,
    body: -> { { filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([
          { site_id: site.id,
            coverage: [
              audio_recording.recorded_date.utc.as_json,
              (audio_recording.recorded_date.utc + audio_recording.duration_seconds.seconds).as_json
            ],
            density: 1.0,
            gap_threshold: 31 }
        ])
      end
    })

  with_custom_action(:analysis_coverage, path: 'analysis_coverage', verb: :post,
    body: -> { { filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([
          { site_id: site.id,
            result: AnalysisJobsItem::RESULT_SUCCESS,
            coverage: [
              audio_recording.recorded_date.utc.as_json,
              (audio_recording.recorded_date.utc + audio_recording.duration_seconds.seconds).as_json
            ],
            density: 1.0,
            gap_threshold: 31 }
        ])
      end
    })

  with_custom_action(:tag_accumulation, path: 'tag_accumulation', verb: :post,
    body: -> { { options: { bucket_size: 'day' }, filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([{ bucket: [day, day + 1.day], cumulative_unique_tag_count: 1.0 }])
      end
    })

  with_custom_action(:tag_frequency, path: 'tag_frequency', verb: :post,
    body: -> { { options: { bucket_size: 'day' }, filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([{ bucket: [day, day + 1.day], tags: [{ tag_id: tag.id, events: 1 }] }])
      end
    })

  with_custom_action(:tag_diel_activity, path: 'tag_diel_activity', verb: :post,
    body: -> { { options: { bucket_size: 'hour' }, filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_data).to match((0..23).map { |i| { bucket: [i * 3600, (i + 1) * 3600], tags: [] } })
      else
        expect(api_data).to match(
            (0..23).map { |i|
              bucket_lower = i * 3600
              tags = bucket_lower == 25_200 ? [{ tag_id: tag.id, events: 1 }] : []
              { bucket: [bucket_lower, bucket_lower + 3600], tags: tags }
            }
          )
      end
    })

  with_custom_action(:event_summaries, path: 'event_summaries', verb: :post,
    body: -> { { options: {}, filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([
          { tag_id: tag.id,
            provenance_id: nil,
            events: 1,
            score_mean: nil,
            score_stddev: nil,
            score_minimum: nil,
            score_maximum: nil,
            score_histogram: nil }
        ])
      end
    })

  # Any authenticated user with at least reader access can use the reports/* endpoints
  ensures :admin, :owner, :writer, :reader,
    can: [:recording_coverage, :analysis_coverage, :tag_accumulation, :tag_frequency, :tag_diel_activity, :event_summaries],
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Users without project access can call these endpoints, but receive no visible tag results
  ensures :no_access,
    can: [:recording_coverage, :analysis_coverage, :tag_accumulation, :tag_frequency, :tag_diel_activity,
          :event_summaries],
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Harvester cannot access the endpoint
  ensures :harvester,
    cannot: [:recording_coverage, :analysis_coverage, :tag_accumulation, :tag_frequency, :tag_diel_activity,
             :event_summaries],
    fails_with: :forbidden

  ensures :harvester,
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Anonymous users cannot access the endpoint
  ensures :anonymous,
    cannot: [:recording_coverage, :analysis_coverage, :tag_accumulation, :tag_frequency, :tag_diel_activity,
             :event_summaries],
    fails_with: :unauthorized

  ensures :anonymous,
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Invalid tokens cannot access the endpoint
  ensures :invalid,
    cannot: [:recording_coverage, :analysis_coverage, :tag_accumulation, :tag_frequency, :tag_diel_activity, :event_summaries,
             :index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: [:unauthorized, :not_found]
end
