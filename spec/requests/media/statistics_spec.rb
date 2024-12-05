# frozen_string_literal: true

describe '/audio_recordings/:audio_recording_id/original(.:format)', :aggregate_failures do
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  let(:lt_recording) {
    create(
      :audio_recording,
      recorded_date: Time.zone.parse('2019-09-13T00:00:01+1000 '),
      duration_seconds: audio_file_bar_lt_metadata[:duration_seconds],
      media_type: audio_file_bar_lt_metadata[:format],
      original_file_name: Fixtures.bar_lt_file.basename,
      status: :ready,
      site:
    )
  }

  before do
    clear_audio_cache

    # backfill our audio storage with a fixture
    @test_file = link_original_audio(
      target: Fixtures.bar_lt_file,
      uuid: lt_recording.uuid,
      datetime_with_offset: lt_recording.recorded_date,
      original_format: audio_file_bar_lt_metadata[:format]
    )

    Permission.create!(
      project_id: project.id,
      user_id: nil,
      allow_anonymous: true,
      level: 'reader',
      creator: owner_user
    )
  end

  after(:all) do
    @test_file&.unlink
  end

  def expect_stats(
    user_segment, user_original, user_duration,
    recording_segment, recording_original, recording_segment_duration
  )
    expected = {
      audio_download_duration: user_duration.nil? ? nil : a_value_within(0.001).of(user_duration.to_d),
      audio_segment_download_count: user_segment,
      audio_original_download_count: user_original,
      original_download_count: recording_original,
      segment_download_count: recording_segment,
      segment_download_duration: recording_segment_duration.nil? ? nil : a_value_within(0.001).of(recording_segment_duration.to_d)
    }

    if user.nil?
      expect(Statistics::UserStatistics.count).to eq 0

      Statistics::AnonymousUserStatistics.totals
    else
      expect(Statistics::AnonymousUserStatistics.count).to eq 0

      Statistics::UserStatistics.totals_for(user)
    end => sum

    actual = {}.merge(
      Statistics::AudioRecordingStatistics.totals_for(lt_recording),
      sum
    )

    expect(actual).to match a_hash_including(expected)
  end

  def media_url(start_offset, end_offset, format = '.wav')
    "/audio_recordings/#{lt_recording.id}/media#{format}?start_offset=#{start_offset}&end_offset=#{end_offset}"
  end

  def original_url
    "/audio_recordings/#{lt_recording.id}/original"
  end

  # these tests are slow because we're actually generating a bunch of media
  # segments. I thought about faking media generation but every fake adds
  # technical debt (see "Why mocking is bad)" and it would be more effort to
  # disable a working service.
  context 'with the admin user', :slow do
    let(:user) { admin_user }
    let(:token) { admin_token }
    let(:headers) { media_request_headers(admin_token) }

    it 'counts segment downloads' do
      get(media_url(0, 30), headers:)

      expect_success
      expect_stats(1, 0, 30.0, 1, 0, 30.0)
    end

    if it 'counts original downloads' do
         get(original_url, headers:)

         expect_success
         expect_stats(0, 1, audio_file_bar_lt_metadata[:duration_seconds], 0, 1, 0)
       end

      it 'counts a mix of downloads' do
        get(media_url(0, 30), headers:)
        get(original_url, headers:)
        get(media_url(10.5, 30), headers:)
        get(original_url, headers:)
        get(media_url(5000, 5300), headers:)

        duration = (audio_file_bar_lt_metadata[:duration_seconds] * 2) + 30 + 19.5 + 300
        expect_stats(3, 2, duration, 3, 2, 30 + 19.5 + 300)
        expect(Statistics::AudioRecordingStatistics.count).to eq 1
      end

      it 'does not count HEAD requests' do
        head(media_url(0, 30), headers:)
        expect_success

        expect_stats(nil, nil, nil, nil, nil, nil)
        expect(Statistics::AudioRecordingStatistics.count).to eq 0
      end

      it 'does not count json requests' do
        head media_url(0, 30, '.json'), headers: media_request_headers(token, format: '.json')
        expect_success

        expect_stats(nil, nil, nil, nil, nil, nil)
        expect(Statistics::AudioRecordingStatistics.count).to eq 0
      end

      it 'does not count spectrogram requests' do
        head media_url(0, 30, '.png'), headers: media_request_headers(token, format: '.png')
        expect_success

        expect_stats(nil, nil, nil, nil, nil, nil)
        expect(Statistics::AudioRecordingStatistics.count).to eq 0
      end

      it 'does not count failed requests' do
        get(media_url(90, 30), headers:)
        expect(response).to have_http_status(:unprocessable_content)

        expect_stats(nil, nil, nil, nil, nil, nil)
        expect(Statistics::AudioRecordingStatistics.count).to eq 0
      end
    end

    # anonymous users should never have access to the original endpoint
    context 'with an anonymous user', :slow do
      let(:user) {  nil }
      let(:token) { anonymous_token }
      let(:headers) { media_request_headers(anonymous_token) }

      it 'counts segment downloads' do
        get(media_url(0, 30), headers:)

        expect_success
        expect_stats(1, 0, 30.0, 1, 0, 30.0)
      end

      it 'counts a mix of downloads' do
        get(media_url(0, 30), headers:)

        get(media_url(10.5, 30), headers:)

        get(media_url(5000, 5300), headers:)

        expect_stats(3, 0, 30 + 19.5 + 300, 3, 0, 30 + 19.5 + 300)
        expect(Statistics::AudioRecordingStatistics.count).to eq 1
      end
    end
  end
end
