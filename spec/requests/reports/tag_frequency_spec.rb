# frozen_string_literal: true

describe 'reports/tag_frequency' do
  create_audio_recordings_hierarchy

  let(:recording_start) { Time.parse('2000-03-06 07:06:59Z').utc }
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
    let(:final_bucket_array) {
      [a_hash_including(tag_id: tags[2].id, events: 2)]
    }

    let(:expected_buckets) do
      rec1, rec2, rec3, rec4 = recordings.map { |recording| recording.recorded_date.utc.at_beginning_of_day }
      [
        { bucket: [rec1, rec1 + period], tags: array_including(a_hash_including(tag_id: tags[0].id, events: 1), a_hash_including(tag_id: tags[1].id, events: 1)) }, #nolint
        { bucket: [rec2, rec2 + period], tags: [a_hash_including(tag_id: tags[0].id, events: 2)] },
        { bucket: [rec3, rec3 + period], tags: [] },
        { bucket: [rec4, rec4 + period], tags: final_bucket_array }
      ]
    end

    it 'returns the correct buckets and tag frequency arrays' do
      post '/reports/tag_frequency', params: body, **api_headers(writer_token)

      expect_success
      expect(api_data).to match(expected_buckets)
    end

    context 'with filter by tag' do
      let(:body) do
        {
          options: { bucket_size: 'day' },
          filter: { 'tags.id': { in: [tags.first.id, tags.second.id] } }
        }
      end

      it 'returns bucketed tag frequency only for audio events with the specified tag' do
        post '/reports/tag_frequency', params: body, **api_headers(writer_token)
        expect_success
        expect(api_data).to match expected_buckets[0..1]
      end
    end

    context 'with multiple tags per audio event' do
      let!(:new_tagging) {
        existing_event = recordings.last.audio_events.first
        create(:tagging, tag: create(:tag, creator: writer_user), audio_event: existing_event)
      }

      let(:final_bucket_array) {
        [a_hash_including(tag_id: tags[2].id, events: 2), a_hash_including(tag_id: new_tagging.tag.id, events: 1)]
      }

      it 'counts unique tags correctly' do
        post '/reports/tag_frequency', params: body, **api_headers(writer_token)
        expect_success
        expect(api_data).to match expected_buckets
      end
    end
  end

  context 'with bucket size of week' do
    it 'returns the correct buckets and counts' do
      body = { options: { bucket_size: 'week' }, filter: {} }
      expected = [
        {
          bucket: [
            recording_start.utc.at_beginning_of_week(:monday),
            recording_start.utc.at_beginning_of_week(:monday) + 1.week
          ],
          tags: array_including(a_hash_including(tag_id: tags[0].id, events: 3),
            a_hash_including(tag_id: tags[1].id, events: 1), a_hash_including(tag_id: tags[2].id, events: 2))
        }
      ]

      post '/reports/tag_frequency', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  context 'with bucket size of month' do
    let(:recording_start) { Time.parse('2000-01-01 00:00:59Z').utc }
    let(:period) { 2.months }

    it 'returns the correct buckets and counts' do
      body = { options: { bucket_size: 'month' }, filter: {} }
      bucket_one = recording_start.utc.at_beginning_of_month

      expected = [
        { bucket: [bucket_one, bucket_one + 1.month],
          tags: array_including(
            a_hash_including(tag_id: tags[0].id, events: 1),
            a_hash_including(tag_id: tags[1].id, events: 1)
          ) },
        { bucket: [bucket_one + 1.month, bucket_one + 2.months], tags: [] },
        { bucket: [bucket_one + 2.months, bucket_one + 3.months],
          tags: array_including(
            a_hash_including(tag_id: tags[0].id, events: 2)
          ) },
        { bucket: [bucket_one + 3.months, bucket_one + 4.months], tags: [] },
        { bucket: [bucket_one + 4.months, bucket_one + 5.months], tags: [] },
        { bucket: [bucket_one + 5.months, bucket_one + 6.months], tags: [] },
        { bucket: [bucket_one + 6.months, bucket_one + 7.months],
          tags: array_including(
            a_hash_including(tag_id: tags[2].id, events: 2)
          ) }
      ]

      post '/reports/tag_frequency', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  context 'with bucket size of year' do
    let(:recording_start) { Time.parse('2000-01-01 00:00:59Z').utc }
    let(:period) { 5.months }

    it 'returns the correct buckets and counts' do
      body = { options: { bucket_size: 'year' }, filter: {} }
      bucket_one = recording_start.utc.at_beginning_of_year
      expected = [
        {
          bucket: [bucket_one, bucket_one + 1.year],
          tags: array_including(
            a_hash_including(tag_id: tags[0].id, events: 3),
            a_hash_including(tag_id: tags[1].id, events: 1)
          )
        },
        {
          bucket: [bucket_one + 1.year, bucket_one + 2.years],
          tags: array_including(
            a_hash_including(tag_id: tags[2].id, events: 2)
          )
        }
      ]

      post '/reports/tag_frequency', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end
end
