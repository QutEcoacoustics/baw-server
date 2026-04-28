# frozen_string_literal: true

describe 'reports/recording_coverage' do
  create_entire_hierarchy
  # start 1 day after the existing audio recording
  let(:recording_first_start) { audio_recording.recorded_date + 1.day }
  let(:duration) { 5.minutes }

  before do
    #
    #       rec1                      rec2
    # :00          :05          :10          :15
    #  |------------|            |------------|
    #
    #  |**************************************|

    # group 1 - testing that recordings with gaps smaller than the threshold are grouped together, density calculated correctly
    first_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: recording_first_start, duration_seconds: duration)

    second_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: recording_first_start + (2 * duration), duration_seconds: duration)

    # group 2 - no gaps, multiple recordings with varied start/end times
    third_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: recording_first_start + (4 * duration) + 30.seconds, duration_seconds: duration)

    fourth_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: recording_first_start + (4 * duration) + 30.seconds, duration_seconds: 60.seconds)

    fifth_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: recording_first_start + (5 * duration), duration_seconds: 10.minutes)

    # group 3 - final recording ends exactly 1 week after the existing audio_recording starts, to give a gap threshold of 5 minutes and 15 seconds
    final_recording = create(:audio_recording, creator: writer_user, site: site,
      recorded_date: audio_recording.recorded_date + (7.days - duration), duration_seconds: duration)
  end

  it 'works' do
    post '/reports/recording_coverage', params: { filter: {} }, **api_headers(writer_token)
    expect_success
  end
end
