# frozen_string_literal: true

describe 'reports/recording_coverage' do
  create_entire_hierarchy
  let(:start_date) { audio_recording.recorded_date.utc }
  let(:duration_seconds) { audio_recording.duration_seconds }
  let(:end_date) { start_date + 7.days }
  let(:gap_threshold) { (end_date - start_date) / 1920 }
  let(:gap_below_threshold) { 5.minutes }
  let(:gap_above_threshold) { 10.minutes }

  let(:expected_data) do
    # density calculation for two recordings of same length, separated by `gap_below_threshold`:
    density = (duration_seconds + duration_seconds).seconds /
              ((duration_seconds + duration_seconds).seconds + gap_below_threshold)

    [{ site_id: site.id,
       coverage: [
         start_date,
         start_date + duration_seconds + gap_below_threshold + duration_seconds
       ],
       density: be_within(0.0001).of(density),
       gap_threshold: },

     { site_id: site.id,
       coverage: [end_date - duration_seconds, end_date],
       density: 1.0,
       gap_threshold: }]
  end

  before do
    # Start 5 minutes after the first recording ends (i.e. within the gap threshold), so they group together
    create(:audio_recording,
      creator: writer_user, site:, recorded_date: recording_end_date(audio_recording) + gap_below_threshold, duration_seconds:)

    # Make a recording that will act as the upper for the entire set of audio recordings;
    # ending exactly 1 week after the first audio_recording starts, resulting in a known gap threshold of 5 minutes 15 seconds
    create(:audio_recording, creator: writer_user, site:, recorded_date: end_date - duration_seconds, duration_seconds:)

    # Create a recording that writer_user has no access to, to prove it is not included in the coverage
    create(:audio_recording, recorded_date: start_date, duration_seconds: 600_000)
  end

  it 'returns the correct coverage values' do
    post '/reports/recording_coverage', params: { filter: {} }, **api_headers(writer_token)

    expect_success
    expect(api_data).to match_array(expected_data)
  end

  context 'with multiple sites' do
    let(:another_site) { create(:site, creator: writer_user, region: region, projects: [project]) }

    # recordings separated by > gap threshold
    before do
      create(:audio_recording,
        creator: writer_user, site: another_site, recorded_date: start_date, duration_seconds: 5.minutes) => another_site_recording
      create(:audio_recording,
        creator: writer_user, site: another_site, recorded_date: recording_end_date(another_site_recording) + gap_above_threshold, duration_seconds: 5.minutes)
    end

    let!(:additional_site_expected_data) do
      [*expected_data,
       { site_id: another_site.id, coverage: [start_date, start_date + 5.minutes], density: 1.0, gap_threshold: },
       { site_id: another_site.id,
         coverage: [
           start_date + 5.minutes + gap_above_threshold,
           start_date + 5.minutes + gap_above_threshold + 5.minutes
         ],
         density: 1.0,
         gap_threshold: }]
    end

    it 'returns the correct coverage values, partitioned by site' do
      post '/reports/recording_coverage', params: { filter: {} }, **api_headers(writer_token)

      expect_success
      expect(api_data).to match_array(additional_site_expected_data)
    end

    context 'with filters' do
      let(:filter) { { filter: { site_id: { not_eq: another_site.id } } } }

      it 'returns the correct coverage values, excluding filtered recordings' do
        post '/reports/recording_coverage', params: filter, **api_headers(writer_token)

        expect_success
        expect(api_data).to match_array(expected_data)
      end
    end
  end

  def recording_end_date(recording) = recording.recorded_date.utc + recording.duration_seconds.seconds
end
