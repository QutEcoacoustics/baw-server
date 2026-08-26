# frozen_string_literal: true

describe Api::Reporting::Bucketer do
  create_audio_recordings_hierarchy

  # The bucketer produces buckets two ways that must agree: #bucket_ctes builds
  # the full series of buckets spanning the data, while #bucket assigns a single
  # row to a bucket directly. Reports group rows with #bucket and then join to
  # the series, so a row's assigned bucket must be identical to the series bucket
  # that covers it.

  # The events are spread across the year to exercise the agreement between #bucket (row
  # assignment) and #bucket_ctes (series generation):
  #   - Tuesday and Thursday share a week, but not a day.
  #   - The three March events share a month, but not a week.
  #   - The June event shares a year with the others, but not a month.
  let(:wednesday_event) {
    recording = create(:audio_recording, site:, creator: writer_user,
      recorded_date: Time.zone.parse('2000-03-08T00:00:00Z'))
    create(:audio_event, audio_recording: recording, creator: writer_user, start_time_seconds: 0, end_time_seconds: 1)
  }
  let(:tuesday_event) {
    recording = create(:audio_recording, site:, creator: writer_user,
      recorded_date: Time.zone.parse('2000-03-14T00:00:00Z'))
    create(:audio_event, audio_recording: recording, creator: writer_user, start_time_seconds: 0, end_time_seconds: 1)
  }
  let(:thursday_event) {
    recording = create(:audio_recording, site:, creator: writer_user,
      recorded_date: Time.zone.parse('2000-03-16T00:00:00Z'))
    create(:audio_event, audio_recording: recording, creator: writer_user, start_time_seconds: 0, end_time_seconds: 1)
  }
  let(:june_event) {
    recording = create(:audio_recording, site:, creator: writer_user,
      recorded_date: Time.zone.parse('2000-06-08T00:00:00Z'))
    create(:audio_event, audio_recording: recording, creator: writer_user, start_time_seconds: 0, end_time_seconds: 1)
  }

  let(:all_events) { [wednesday_event, tuesday_event, thursday_event, june_event] }

  let(:events) { Arel::Table.new(:filtered_events) }

  # Returns the EVENTS CTE, exposing id, start_at, and end_at columns, in the
  # same shape the report templates feed to the bucketer.
  let(:events_cte) {
    query = AudioEvent
      .joins(:audio_recording)
      .select(
        AudioEvent.arel_table[:id].as('id'),
        AudioEvent.start_date_arel.as('start_at'),
        AudioEvent.end_date_arel.as('end_at')
      ).arel

    Arel::Nodes::As.new(events, query)
  }

  # Runs the generated bucket series and returns its list of bucket ranges.
  let(:series_buckets) {
    buckets = Api::Reporting::Bucketer::BUCKETS

    query = buckets
      .project(buckets[:bucket], buckets[:bucket].lower.as('bucket_lower'))
      .with(events_cte, *bucketer.bucket_ctes(events_table: events))
      .order(buckets[:bucket].lower)

    AudioEvent.exec_query_casted(query).pluck(:bucket)
  }

  # Runs the bucketer's #bucket method against the events and returns a hash of
  # each event's id to the bucket it was assigned.
  let(:assigned_buckets) {
    query = events
      .project(events[:id], bucketer.bucket(column: events[:start_at]).as('bucket'))
      .with(events_cte)

    AudioEvent.exec_query_casted(query).to_h { |row| [row[:id], row[:bucket]] }
  }

  shared_examples 'a time bucketer' do
    it 'assigns each event to a bucket that contains its start time' do
      all_events.each do |event|
        expect(assigned_buckets[event.id]).to cover(event.start_date)
      end
    end

    # For each event, find the series bucket that covers its start time, then
    # check the bucket #bucket assigned is that same bucket. Reports rely on this
    # to join each row to its bucket in the series.
    it 'assigns the same bucket the series produced' do
      all_events.each do |event|
        expect(assigned_buckets[event.id]).to eq(series_buckets.find { |bucket| bucket.cover?(event.start_date) })
      end
    end
  end

  ['day', 'week', 'month', 'year'].each do |bucket_size|
    context "when the bucket size is #{bucket_size}" do
      let(:bucketer) { Api::Reporting::Bucketer.new(bucket_size:) }

      it_behaves_like 'a time bucketer'
    end
  end
end
