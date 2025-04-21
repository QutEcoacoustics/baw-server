# frozen_string_literal: true

describe 'Audio Event Reports' do
  # create unique users that will be available to confirm events
  let(:users) { create_list(:user, 3) }
  let(:creator) { users.first }
  let(:provenance) { create(:provenance, creator: creator) }
  let(:start_date) { DateTime.parse('2025-01-01T00:00:00Z', nil) }
  let(:tags) {
    tag_keys = [:koala, :whip_bird, :honeyeater, :magpie]
    tag_keys.index_with { |tag_name| create(:tag, text: tag_name) }
  }

  let(:project) { create(:project, creator: creator) }
  let(:region) { create(:region, project: project, creator: creator) }
  let(:site_one) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }
  let(:site_two) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }

  let(:data) {
    { project: project,
      sites: [site_one, site_two],
      recordings: [
        with_recording(site: site_one, creator: creator, date: start_date) { |recording|
          with_event(recording:, start: 5, tag: tags[:koala])
          with_event(recording:, start: 3600, tag: tags[:koala])
          with_event(recording:, start: 7600, tag: tags[:whip_bird],
            confirmations: ['correct', 'correct'], users: users)
        },
        with_recording(site: site_two, creator: creator, date: start_date + 2.days) { |recording|
          with_event(recording:, start: 5, tag: tags[:koala])
        },
        with_recording(site: site_one, creator: creator, date: start_date + 2.days) { |recording|
          with_event(recording:, start: 18_000, tag: tags[:koala])
        },
        with_recording(site: site_one, creator: creator, date: start_date + 4.days),
        with_recording(site: site_one, creator: creator, date: start_date + 6.days) { |recording|
          with_event(recording:, start: 5, tag: tags[:koala])
          with_event(recording:, start: 3600, tag: tags[:whip_bird])
          with_event(recording:, start: 7600, tag: tags[:honeyeater])
          with_event(recording:, start: 18_000, tag: tags[:magpie],
            confirmations: ['correct', 'incorrect', 'incorrect'], users: users)
        }
      ] }
  }

  let(:writer_token) { Creation::Common.create_user_token(creator) }
  let(:default_filter) {
    {
      filter: {},
      options: {
        bucket_size: 'day',
        start_date: start_date,
        end_date: start_date + 7.days
      }
    }
  }

  it 'default entry' do
    expect(data).to include(:project)
    debugger
  end

  it 'accepts a bucket size option param' do
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)

    expect(response).to have_http_status(:ok)
  end

  it 'returns events a user has permission to view' do
    not_my_recording_and_site = create(:audio_recording) { |recording|
      create(:audio_event_with_tags, audio_recording: recording, creator: recording.creator)
    }

    post '/audio_event_reports', params: { filter: {} }, **api_with_body_headers(writer_token)
  end
end

# Create a recording with default values from current scope
# yield the recording to a block or else return it
def with_recording(site:, creator:, date:)
  recording = create(:audio_recording, site: site, creator: creator, recorded_date: date)
  block_given? ? yield(recording) : recording
end

# Create event with default values from current scope
# @param [Hash] args optional arguments for creating verifications
# @option [Array<String>] :confirmations verification confirmation values
# @option [Array<User>] :users to confirm the event, length >= confirmations
# @return the audio_recording used to create the event
def with_event(recording:, start: 5, tag: tags.values.first, **args)
  create(:audio_event_tagging, audio_recording: recording, creator: creator,
    start_time_seconds: start, provenance:, tag:, **args)
  recording
end
