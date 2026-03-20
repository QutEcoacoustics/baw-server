# frozen_string_literal: true

describe 'reports/tag_accumulation' do
  create_audio_recordings_hierarchy

  let(:tags) { create_list(:tag, 3, creator: writer_user) }
  let(:which_tags) { [[0, 1], [0, 0], nil, [2, 2]] }
  let(:recordings) {
    which_tags.map do |index|
      recording = create(:audio_recording, site: site, creator: writer_user)

      if index
        tags.fetch_values(*index).each do |tag|
          create(:audio_event_using_tag, audio_recording: recording, creator: writer_user, tag: tag)
        end
      end

      recording
    end
  }

  context('with bucket size of day') do
    it 'returns the correct buckets and ccounts' do
      body = {
        options: { bucket_size: 'day' },
        filter: {}
      }

      expected = recordings.each_with_index.map { |recording, i|
        bucket_lower = recording.recorded_date.utc.at_beginning_of_day
        bucket_upper = bucket_lower + 1.day
        bucket = "#{bucket_lower}...#{bucket_upper}"

        a_hash_including(
          bucket: match(bucket),
          cumulative_unique_tag_count: which_tags[0..i].compact.flatten.uniq.size
        )
      }

      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  context('with bucket size of week') do
    it 'returns the correct buckets and counts' do
      body = {
        options: { bucket_size: 'week' },
        filter: {}
      }

      # Get week start and the cumulative unique tag count up to that week, for each recording
      weeks = {}
      recordings.each_with_index do |recording, i|
        week_start = recording.recorded_date.utc.at_beginning_of_week(:monday)
        weeks[week_start] = which_tags[0..i].compact.flatten.uniq.size
      end

      expected = weeks.map { |week_start, count|
        a_hash_including(
          bucket: match("#{week_start}...#{week_start + 1.week}"),
          cumulative_unique_tag_count: count
        )
      }

      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end
end
