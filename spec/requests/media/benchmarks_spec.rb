# frozen_string_literal: true

describe '/audio_recordings/:audio_recording_id/original(.:format)', type: :request, aggregate_failures: true do
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
  end

  after(:all) do
    @test_file&.unlink
  end

  def media_url(start_offset, end_offset)
    "/audio_recordings/#{lt_recording.id}/media.wav?start_offset=#{start_offset}&end_offset=#{end_offset}"
  end

  context 'without fast cache', :slow do
    before do
      Settings.actions.media.cache_to_redis = false
      expect(Settings.actions.media.cache_to_redis).to be false
    end

    after do
      Settings.actions.media.cache_to_redis = true
    end

    example 'generated media requests via disk cache are quick' do
      expect {
        get media_url(0, 30), headers: media_request_headers(reader_token)
      }.to perform_under(4).sec.warmup(0)

      expect_success
      expect(response.content_type).to eq('audio/wav')
      expect(response.content_length).to be_within(100).of(1_323_078)

      expect(response.headers[MediaPoll::HEADER_KEY_RESPONSE_FROM]).to eq MediaPoll::HEADER_VALUE_RESPONSE_REMOTE
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_TOTAL].to_f).to be_within(0.6).of(2.7)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_PROCESSING].to_f).to be_within(0.6).of(2.7)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_WAITING].to_f).to be_within(0.1).of(0.0)

      expect(response.headers['X-Error-Message']).to be_nil
    end

    example 'pre-generated media requests via disk cache are very quick' do
      get media_url(0, 30), headers: media_request_headers(reader_token)
      expect_success

      expect {
        get media_url(0, 30), headers: media_request_headers(reader_token)
      }.to perform_under(1).sec.warmup(0)

      expect_success
      expect(response.content_type).to eq('audio/wav')
      expect(response.content_length).to be_within(100).of(1_323_078)

      expect(response.headers[MediaPoll::HEADER_KEY_RESPONSE_FROM]).to eq MediaPoll::HEADER_VALUE_RESPONSE_CACHE
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_TOTAL].to_f).to be_within(0.1).of(0.01)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_PROCESSING].to_f).to be_within(0).of(0)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_WAITING].to_f).to be_within(0.1).of(0)

      expect(response.headers['X-Error-Message']).to be_nil
    end

    example 'generated media requests via disk cache are quick, even near the end of the file' do
      expect {
        get media_url(6000, 6030), headers: media_request_headers(reader_token)
      }.to perform_under(4).sec.warmup(0)

      expect_success
      expect(response.content_type).to eq('audio/wav')
      expect(response.content_length).to be_within(100).of(1_323_078)

      expect(response.headers[MediaPoll::HEADER_KEY_RESPONSE_FROM]).to eq MediaPoll::HEADER_VALUE_RESPONSE_REMOTE
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_TOTAL].to_f).to be_within(1).of(3.25)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_PROCESSING].to_f).to be_within(1).of(3.25)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_WAITING].to_f).to be_within(0.1).of(0.0)

      expect(response.headers['X-Error-Message']).to be_nil
    end
  end

  context 'with fast cache' do
    before do
      Settings.actions.media.cache_to_redis = true
    end

    it 'expects fast cache to be enabled' do
      expect(Settings.actions.media.cache_to_redis).to be true
    end

    example 'generated media requests can be fetched from the fast cache' do
      expect {
        get media_url(0, 30), headers: media_request_headers(reader_token)
      }.to perform_under(4).sec.warmup(0)

      expect_success
      expect(response.content_type).to eq('audio/wav')
      expect(response.content_length).to be_within(100).of(1_323_078)

      expect(response.headers[MediaPoll::HEADER_KEY_RESPONSE_FROM]).to eq MediaPoll::HEADER_VALUE_RESPONSE_REMOTE_CACHE
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_TOTAL].to_f).to be_within(0.5).of(2.9)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_PROCESSING].to_f).to be_within(0.5).of(2.8)
      expect(response.headers[MediaPoll::HEADER_KEY_ELAPSED_WAITING].to_f).to be_within(0.1).of(0.01)

      expect(response.headers['X-Error-Message']).to be_nil
    end
  end
end
