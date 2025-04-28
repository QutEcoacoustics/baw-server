# frozen_string_literal: true

describe 'Audio Event Reports' do
  # create unique users that will be available to confirm events
  let(:users) { create_list(:user, 4) }
  let(:creator) { users.first }
  let(:provenance) { create(:provenance, creator: creator) }
  let(:start_date_string) { '2025-01-01T00:00:00Z' }
  let(:start_date) { DateTime.parse(start_date_string, nil) }
  let(:tags) {
    tag_keys = [:koala, :whip_bird, :honeyeater, :magpie]
    tag_keys.index_with { |tag_name| create(:tag, text: tag_name) }
  }

  let(:project) { create(:project, creator: creator) }
  let(:region) { create(:region, project: project, creator: creator) }
  let(:site_one) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }
  let(:site_two) { create(:site_with_lat_long, projects: [project], region: region, creator: creator) }

  let!(:data) {
    { project: project,
      sites: [site_one, site_two],
      recordings: [
        with_recording(site: site_one, creator: creator, date: start_date) { |recording|
          with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
          with_event(creator: creator, provenance: provenance, recording:, start: 3600, tag: tags[:koala])
          with_event(creator: creator, provenance: provenance, recording:, start: 7600, tag: tags[:whip_bird],
            confirmations: ['correct', 'correct'], users: users)
        },
        with_recording(site: site_two, creator: creator, date: start_date + 2.days) { |recording|
          with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
        },
        with_recording(site: site_one, creator: creator, date: start_date + 2.days) { |recording|
          with_event(creator: creator, provenance: provenance, recording:, start: 18_000, tag: tags[:koala])
          with_event(creator: creator, provenance: provenance, recording:, start: 20_000, tag: tags[:koala],
            confirmations: ['correct', 'correct', 'correct', 'incorrect'], users: users)
        },
        with_recording(site: site_one, creator: creator, date: start_date + 6.days) { |recording|
          with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
          with_event(creator: creator, provenance: provenance, recording:, start: 3600, tag: tags[:whip_bird],
            confirmations: ['incorrect', 'incorrect'], users: users) # whip bird should have average of 1 consensus; verifiers are always in agreement
          with_event(creator: creator, provenance: provenance, recording:, start: 7600, tag: tags[:honeyeater])
          with_event(creator: creator, provenance: provenance, recording:, start: 18_000, tag: tags[:magpie],
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
        start_time: start_date,
        end_time: start_date + 7.days
      }
    }
  }

  it 'returns expected values' do
    # to get two different tags on one audio event and we expect to see sum of
    # counts for event summaries to be greater than the number of actual audio events
    create(:tagging, audio_event: AudioEvent.last)
    post '/audio_event_reports', params: default_filter, **api_with_body_headers(writer_token)
    expect(response).to have_http_status(:ok)
    debugger
    expected_site_ids = data[:sites].pluck(:id).join(',')
    expect(api_result.first[:site_ids]).to match(expected_site_ids)

    expected_recording_ids = data[:recordings].pluck(:id).join(',')
    expect(api_result.first[:audio_recording_ids]).to match(expected_recording_ids)
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
