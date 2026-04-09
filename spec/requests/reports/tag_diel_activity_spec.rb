# frozen_string_literal: true

describe 'reports/tag_diel_activity' do
  create_audio_recordings_hierarchy

  let(:recording_start) { Time.parse('2000-03-06 07:06:59Z').utc }

  let(:tags) { create_list(:tag, 3, creator: writer_user) }

  let(:which_tags) { [[0, 1], [0, 0], nil, [2, 2]] }

  let(:period) { 1.day + 1.hour }

  let!(:recordings) do
    which_tags.map.with_index do |index, i|
      recording = create(
        :audio_recording,
        site: site,
        creator: writer_user,
        recorded_date: recording_start + (i * period)
      )

      if index
        tags.fetch_values(*index).each do |tag|
          create(
            :audio_event_using_tag,
            audio_recording: recording,
            creator: writer_user,
            tag: tag
          )
        end
      end

      recording
    end
  end

  let(:final_bucket_array) { [a_hash_including(tag_id: tags[2].id, events: 2)] }
  let(:result_buckets) do
    {
      25_200 => array_including(a_hash_including(tag_id: tags[0].id, events: 1), a_hash_including(tag_id: tags[1].id, events: 1)), #nolint
      28_800 => [a_hash_including(tag_id: tags[0].id, events: 2)],
      32_400 => [],
      36_000 => final_bucket_array
    }
  end

  let(:expected_data) do
    (0..(interval[:buckets] - 1)).map { |i|
      bucket_lower = i * interval[:bucket_size]
      {
        bucket: [bucket_lower, bucket_lower + interval[:bucket_size]],
        tags: result_buckets.fetch(bucket_lower, [])
      }
    }
  end

  before do
    # create an audio_event that writer_user has no access to, to prove it is not included in the counts
    create(:audio_event_with_tags)
  end

  context 'with bucket size of hour' do
    let(:body) { { options: { bucket_size: 'hour' }, filter: {} } }
    let(:interval) { { bucket_size: Api::Reporting::TagDielActivity::INTERVALS['hour'], buckets: 24 } }

    it 'returns the correct buckets and tag frequency arrays' do
      post '/reports/tag_diel_activity', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match(expected_data)
    end

    context 'with filter by tag' do
      let(:body) do
        {
          options: { bucket_size: 'hour' },
          filter: { 'tags.id': { in: [tags.first.id, tags.second.id] } }
        }
      end

      let(:result_buckets) do
        {
          25_200 => array_including(a_hash_including(tag_id: tags[0].id, events: 1), a_hash_including(tag_id: tags[1].id, events: 1)), #nolint
          28_800 => [a_hash_including(tag_id: tags[0].id, events: 2)]
        }
      end

      it 'returns bucketed tag frequency only for audio events with the specified tag' do
        post '/reports/tag_diel_activity', params: body, **api_headers(writer_token)
        expect_success

        expect(api_data).to match expected_data
      end
    end

    context 'with multiple tags per audio event' do
      let!(:new_tagging) {
        existing_event = recordings.last.audio_events.first
        create(:tagging, tag: create(:tag, creator: writer_user), audio_event: existing_event)
      }

      let(:final_bucket_array) {
        array_including(a_hash_including(tag_id: tags[2].id, events: 2),
          a_hash_including(tag_id: new_tagging.tag.id, events: 1))
      }

      it 'counts unique tags correctly' do
        post '/reports/tag_diel_activity', params: body, **api_headers(writer_token)
        expect_success

        expect(api_data).to match expected_data
      end
    end
  end

  context 'with bucket size of halfhour' do
    let(:body) { { options: { bucket_size: 'halfhour' }, filter: {} } }
    let(:interval) { { bucket_size: Api::Reporting::TagDielActivity::INTERVALS['halfhour'], buckets: 48 } }

    # with an offset of 20 minutes between recordings, we expect the second
    # recording's events are pooled into the same bucket as the first
    # recording's events (compared to the hour bucket size context where they
    # are in separate buckets).
    let(:period) { 1.day + 20.minutes }
    let(:result_buckets) do
      {
        25_200 => array_including(a_hash_including(tag_id: tags[0].id, events: 3), a_hash_including(tag_id: tags[1].id, events: 1)), #nolint
        27_000 => [],
        28_800 => final_bucket_array
      }
    end

    it 'returns the correct buckets and tag frequency arrays' do
      post '/reports/tag_diel_activity', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match(expected_data)
    end
  end

  context 'with bucket size of minute' do
    let(:body) { { options: { bucket_size: 'minute' }, filter: {} } }
    let(:interval) { { bucket_size: Api::Reporting::TagDielActivity::INTERVALS['minute'], buckets: 1440 } }

    # with no shift in minutes/hours we expect to see all events end up in the same minute bucket
    let(:period) { 1.day }
    let(:result_buckets) do
      {
        25_620 => array_including(
          a_hash_including(tag_id: tags[0].id, events: 3),
          a_hash_including(tag_id: tags[1].id, events: 1),
          a_hash_including(tag_id: tags[2].id, events: 2)
        )
      }
    end

    it 'returns the correct buckets and tag frequency arrays' do
      post '/reports/tag_diel_activity', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match(expected_data)
    end
  end
end
