# frozen_string_literal: true

describe 'reports/recording_coverage' do
  create_entire_hierarchy
  let(:start_date) { audio_recording.recorded_date.utc }
  let(:duration) { 5.minutes }
  let(:expected_data) {
    density = (audio_recording.duration_seconds + 1.minute).seconds /
              ((audio_recording.duration_seconds + 1.minute).seconds + 5.minutes)

    # 5 minutes and 15 seconds
    gap_threshold = 315

    [{ site_id: 1,
       coverage: [start_date, start_date + audio_recording.duration_seconds.seconds + 5.minutes + 1.minute],
       density: be_within(0.0001).of(density),
       gap_threshold: },

     { site_id: 1, coverage: [start_date + (7.days - 5.minutes), start_date + (7.days - 5.minutes) + 5.minutes],
       density: 1.0, gap_threshold: },

     { site_id: 2, coverage: [start_date, start_date + 10.minutes], density: 1.0, gap_threshold: },

     { site_id: 2, coverage: [start_date + 20.minutes, start_date + 30.minutes], density: 1.0, gap_threshold: }]
  }

  before do
    # Make a recording that ends exactly 1 week after the first audio_recording starts.
    # The gap threhold will be 5 minutes 15 seconds
    create(:audio_recording, creator: writer_user, site: site,
      recorded_date: start_date + (7.days - 5.minutes), duration_seconds: 5.minutes)

    # Make a recording that starts 5 minutes after the first recording ends (within the gap threshold), so they group together
    create(:audio_recording, creator: writer_user, site: site,
      recorded_date: start_date + audio_recording.duration_seconds + 5.minutes, duration_seconds: 1.minute)

    # Make a new site with recordings to verify that partitioning works correctly
    another_site = create(:site, creator: writer_user, region: region, projects: [project])
    create(:audio_recording, creator: writer_user, site: another_site,
      recorded_date: start_date, duration_seconds: 10.minutes)

    # Starts > gap threshold after previous recording ends: separate island
    create(:audio_recording, creator: writer_user, site: another_site,
      recorded_date: start_date + 20.minutes, duration_seconds: 10.minutes)

    # Finally, create a recording that writer_user has no access to, to prove it is not included in the coverage
    create(:audio_recording, recorded_date: start_date, duration_seconds: 600_000)
  end

  it 'returns the correct coverage values' do
    post '/reports/recording_coverage', params: { filter: {} }, **api_headers(writer_token)

    expect_success
    expect(api_data).to match_array(expected_data)
  end
end
