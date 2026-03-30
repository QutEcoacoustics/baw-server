# frozen_string_literal: true

describe 'reports/tag_frequency' do
  create_audio_recordings_hierarchy

  let(:recording_start) { Time.parse('2000-03-06 07:06:59') }
  let(:tags) { create_list(:tag, 3, creator: writer_user) }
  let(:which_tags) { [[0, 1], [0, 0], nil, [2, 2]] }
  let(:period) { 1.day }
  let!(:recordings) {
    start = recording_start
    which_tags.map do |index|
      recording = create(:audio_recording, site: site, creator: writer_user, recorded_date: start)
      if index
        tags.fetch_values(*index).each do |tag|
          create(:audio_event_using_tag, audio_recording: recording, creator: writer_user, tag: tag)
        end
      end

      start += period
      recording
    end
  }

  before do
    # create an audio_event that writer_user has no access to, to prove it is not included in the counts
    create(:audio_event_with_tags)
  end

  context 'with bucket size of day' do
    let(:body) { { options: { bucket_size: 'day' }, filter: {} } }
    let(:expected_buckets) do
      rec1, rec2, rec3, rec4 = recordings.map { |recording| recording.recorded_date.utc.at_beginning_of_day }
      [
        { bucket: [rec1, rec1 + period], tag_id: tags[0].id, events: 1, total_events_in_bucket: 2.0 },
        { bucket: [rec1, rec1 + period], tag_id: tags[1].id, events: 1, total_events_in_bucket: 2.0 },
        { bucket: [rec1, rec1 + period], tag_id: tags[2].id, events: 0, total_events_in_bucket: 2.0 },
        { bucket: [rec2, rec2 + period], tag_id: tags[0].id, events: 2, total_events_in_bucket: 2.0 },
        { bucket: [rec2, rec2 + period], tag_id: tags[1].id, events: 0, total_events_in_bucket: 2.0 },
        { bucket: [rec2, rec2 + period], tag_id: tags[2].id, events: 0, total_events_in_bucket: 2.0 },
        { bucket: [rec3, rec3 + period], tag_id: tags[0].id, events: 0, total_events_in_bucket: 0.0 },
        { bucket: [rec3, rec3 + period], tag_id: tags[1].id, events: 0, total_events_in_bucket: 0.0 },
        { bucket: [rec3, rec3 + period], tag_id: tags[2].id, events: 0, total_events_in_bucket: 0.0 },
        { bucket: [rec4, rec4 + period], tag_id: tags[0].id, events: 0, total_events_in_bucket: 2.0 },
        { bucket: [rec4, rec4 + period], tag_id: tags[1].id, events: 0, total_events_in_bucket: 2.0 },
        { bucket: [rec4, rec4 + period], tag_id: tags[2].id, events: 2, total_events_in_bucket: 2.0 }
      ]
    end

    it 'succeeds' do
      post '/reports/tag_frequency', params: body, **api_headers(writer_token)

      expect_success

      expect(api_data).to match(expected_buckets)
    end
  end
end
