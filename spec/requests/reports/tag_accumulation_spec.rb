# frozen_string_literal: true

describe 'reports/tag_accumulation' do
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
    let(:final_day_count) { 3.0 }
    let(:expected_day_buckets) do
      day1, day2, day3, day4 = recordings.map { |recording| recording.recorded_date.utc.at_beginning_of_day }
      [
        { bucket: [day1, day1 + 1.day], cumulative_unique_tag_count: 2.0 },
        { bucket: [day2, day2 + 1.day], cumulative_unique_tag_count: 2.0 },
        { bucket: [day3, day3 + 1.day], cumulative_unique_tag_count: 2.0 },
        { bucket: [day4, day4 + 1.day], cumulative_unique_tag_count: final_day_count }
      ]
    end

    it 'returns the correct buckets and counts' do
      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)

      expect_success
      expect(api_data).to match expected_day_buckets
    end

    context 'with filter by tag' do
      let(:body) do
        {
          options: { bucket_size: 'day' },
          filter: { 'tags.id': { in: [tags.first.id, tags.second.id] } }
        }
      end

      it 'returns counts only for audio events with the specified tag' do
        post '/reports/tag_accumulation', params: body, **api_headers(writer_token)

        expect_success
        expect(api_data).to match expected_day_buckets[0..1]
      end
    end

    context 'with multiple tags per audio event' do
      let(:final_day_count) { 4.0 }

      before do
        existing_event = recordings.last.audio_events.first
        create(:tagging, tag: create(:tag, creator: writer_user), audio_event: existing_event)
      end

      it 'counts unique tags correctly' do
        post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
        expect_success
        expect(api_data).to match expected_day_buckets
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
          cumulative_unique_tag_count: 3.0
        }
      ]

      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  context 'with bucket size of month' do
    let(:recording_start) { Time.parse('2000-01-01 00:00:59') }
    let(:period) { 2.months }

    it 'returns the correct buckets and counts' do
      body = { options: { bucket_size: 'month' }, filter: {} }
      bucket_one = recording_start.utc.at_beginning_of_month
      expected = [
        { bucket: [bucket_one, bucket_one + 1.month], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 1.month, bucket_one + 2.months], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 2.months, bucket_one + 3.months], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 3.months, bucket_one + 4.months], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 4.months, bucket_one + 5.months], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 5.months, bucket_one + 6.months], cumulative_unique_tag_count: 2.0 },
        { bucket: [bucket_one + 6.months, bucket_one + 7.months], cumulative_unique_tag_count: 3.0 }
      ]

      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  context 'with bucket size of year' do
    let(:recording_start) { Time.parse('2000-01-01 00:00:59') }
    let(:period) { 5.months }

    it 'returns the correct buckets and counts' do
      body = { options: { bucket_size: 'year' }, filter: {} }
      expected = [
        {
          bucket: [recording_start.utc.at_beginning_of_year,
                   recording_start.utc.at_beginning_of_year + 1.year], cumulative_unique_tag_count: 2.0
        },
        {
          bucket: [recording_start.utc.at_beginning_of_year + 1.year,
                   recording_start.utc.at_beginning_of_year + 2.years], cumulative_unique_tag_count: 3.0
        }
      ]

      post '/reports/tag_accumulation', params: body, **api_headers(writer_token)
      expect_success

      expect(api_data).to match expected
    end
  end

  it 'formats correctly as CSV' do
      params = { options: { bucket_size: 'day' }, filter: {} }

      day1 = recordings.min { |recording| recording.recorded_date }.recorded_date.utc.at_beginning_of_day

      post '/reports/tag_accumulation.csv', params:, **api_headers(writer_token, accept: 'text/csv')

      expect_success
      expect(response.content_type).to include('text/csv')

      expected_csv = <<~CSV
        "bucket_lower","bucket_upper","cumulative_unique_tag_count"
        "#{day1.utc.iso8601(3)}","#{(day1 + 1.day).utc.iso8601(3)}","2.0"
      CSV

      expect(response.body).to start_with(expected_csv)
    end
end
