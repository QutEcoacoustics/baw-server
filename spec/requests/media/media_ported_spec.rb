# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/media/media_spec.rb.

describe 'Media segment requests', :aggregate_failures, type: :request do
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  let(:source_audio) { Fixtures.audio_file_mono }
  let(:native_rate) { 44_100 }
  let(:source_channels) { 1 }
  let!(:test_file) {
    audio_recording.update!(
      sample_rate_hertz: native_rate, channels: source_channels,
      duration_seconds: 70, media_type: 'audio/ogg', original_file_name: 'original.ogg'
    )
    link_original_audio(
      target: source_audio, uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date, original_format: 'ogg'
    )
  }

  before do
    clear_audio_cache
    clear_spectrogram_cache
  end

  after do
    test_file.unlink
    clear_audio_cache
    clear_spectrogram_cache
  end

  def request_media(format, params: {}, method: :get, range: false)
    headers = api_request_headers(reader_token)
    headers['Range'] = 'bytes=0-' if range
    process method, "/audio_recordings/#{audio_recording.id}/media.#{format}",
      params: { start_offset: 1, end_offset: 2 }.merge(params), headers:
  end

  def expect_generated_media(media_type, method: :get, range: false)
    expect(response).to have_http_status(range ? :partial_content : :ok)
    expect(response.media_type).to eq(media_type)
    expect(response.content_length).to be_positive
    expect(response.headers['X-Error-Message']).to be_nil

    if media_type == 'application/json'
      expect(response.headers['Accept-Ranges']).to be_nil
      expect(response.headers['Content-Disposition']).to be_nil
      expect(response.headers['Content-Transfer-Encoding']).to be_nil
      (MediaPoll::HEADERS_EXPOSED - ['Content-Length']).each do |header|
        expect(response.headers[header]).to be_nil
      end
    else
      expect(response.headers['Accept-Ranges']).to eq(media_type.start_with?('audio/') ? 'bytes' : nil)
      expect(response.headers['Content-Disposition']).to match(/\Ainline; filename="/)
      expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
      MediaPoll::HEADERS_EXPOSED.each do |header|
        expect(response.headers[header]).to be_present
      end
    end

    if range
      expect(response.headers['Content-Range']).to match(%r{\Abytes 0-\d+/\d+\z})
    else
      expect(response.headers['Content-Range']).to be_nil
    end

    if method == :head
      expect(response.body).to be_empty
    else
      expect(response.body).not_to be_empty
      expect(response.content_length).to eq(response.body.bytesize)
    end
  end

  # media_spec.rb:346-499: all audio formats, spectrogram colour aliases and waveform.
  [
    ['mp3', 'audio/mpeg', {}],
    ['wav', 'audio/wav', {}],
    ['ogg', 'audio/ogg', {}],
    ['webm', 'audio/webm', {}],
    ['flac', 'audio/x-flac', {}],
    ['png', 'image/png', {}],
    ['png', 'image/png', { colour: 'tg' }],
    ['png', 'image/png', { colour: 'teal_green' }],
    ['png', 'image/png', { colour: 'w' }]
  ].each do |format, media_type, params|
    it "serves #{format} #{params} with binary content and media headers" do
      request_media(format, params:)
      expect_generated_media(media_type)
      expect(response.body.b).to start_with("\x89PNG\r\n\x1a\n".b) if format == 'png'

      # media_spec.rb:1062-1080: channel and decimal offset naming regression.
      expect(response.headers['Content-Disposition']).to include('_1_0.wav"') if format == 'wav'
    end
  end

  # media_spec.rb:701-748: a successful HEAD still has the GET representation length.
  [['json', 'application/json'], ['mp3', 'audio/mpeg'], ['png', 'image/png']].each do |format, media_type|
    it "serves HEAD #{format} without a body" do
      request_media(format, method: :head)
      expect_generated_media(media_type, method: :head)
    end
  end

  # media_spec.rb:1020-1059: both generated range-request cases.
  [:get, :head].each do |method|
    it "serves a partial MP3 response for #{method.upcase}" do
      request_media('mp3', method:, range: true)
      expect_generated_media('audio/mpeg', method:, range: true)
    end
  end

  context 'with unsupported formats' do
    it 'rejects a known but unavailable audio format with an empty typed response' do
      request_media('mp4')
      expect(response).to have_http_status(:not_acceptable)
      expect(response.media_type).to eq('audio/mp4')
      expect(response.body).to be_empty
    end

    it 'lists available formats when the extension is unknown' do
      request_media('zjfyrdnd')
      expect(response).to have_http_status(:not_acceptable)
      expect_json_response
      expect(api_result.dig(:meta, :error, :info, :available_formats)).to be_present
    end
  end

  # media_access_spec.rb/media_spec.rb forbidden cases also asserted the error body link.
  it 'offers a permissions request link when media access is forbidden' do
    get "/audio_recordings/#{audio_recording.id}/media.json", headers: api_request_headers(no_access_token)

    expect_error(:forbidden, an_instance_of(String))
    permissions_link = Settings.api_response.error_links_hash[:permissions]
    expect(api_result.dig(:meta, :error, :links)).to include(
      permissions_link[:text].to_sym => permissions_link[:url]
    )
  end

  # These JSON validation cases retain the exact legacy boundary values and
  # details; errors_spec.rb instead checks binary GET/HEAD errors and mail delivery.
  [
    [{ start_offset: 'number' }, 'start_offset parameter must be a decimal number'],
    [{ end_offset: 'number' }, 'end_offset parameter must be a decimal number'],
    [{ end_offset: 71 }, 'smaller than or equal to the duration of the audio recording'],
    [{ end_offset: 0 }, 'must be greater than 0.'],
    [{ start_offset: 70 }, 'smaller than the duration of the audio recording'],
    [{ start_offset: -1 }, 'greater than or equal to 0'],
    [{ start_offset: 9, end_offset: 8 }, 'smaller than end_offset'],
    [{ window_size: 'number' }, 'window_size parameter'],
    [{ window_function: 'number' }, 'window_function parameter'],
    [{ sample_rate: 22 }, 'sample_rate parameter'],
    [{ channel: 2 }, 'channel parameter'],
    [{ colour: 'z' }, 'colour parameter'],
    [
      { sample_rate: '22050user_token=ANAUTHTOKEN' },
      'The request could not be understood: sample_rate parameter (22050user_token=ANAUTHTOKEN) must be an integer'
    ],
    [
      { window_size: '512user_token=ANAUTHTOKEN' },
      'The request could not be understood: window_size parameter (512user_token=ANAUTHTOKEN) must be valid'
    ],
    [
      { channel: '0user_token=ANAUTHTOKEN' },
      'The request could not be understood: channel parameter (0user_token=ANAUTHTOKEN) must be valid'
    ]
  ].each do |params, details|
    it "rejects JSON media parameters #{params}" do
      request_media('json', params:)
      expect_error(:unprocessable_content, a_string_including(details))
    end
  end

  context 'with a non-standard native sample rate' do
    let(:source_audio) { Fixtures.audio_file_stereo_7777hz }
    let(:native_rate) { 7777 }
    let(:source_channels) { 2 }

    it 'serves WAV at the original 7777 Hz sample rate' do
      request_media('wav', params: { sample_rate: 7777 })
      expect_generated_media('audio/wav')
    end

    [['wav', 7776, 'audio/wav'], ['mp3', 7777, 'audio/mpeg']].each do |format, rate, media_type|
      it "rejects unsupported #{format} at #{rate} Hz without a body" do
        request_media(format, params: { sample_rate: rate })
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq(media_type)
        expect(response.body).to be_empty
        expect(response.headers['Content-Length']).to eq('0')
        expect(response.headers['Accept-Ranges']).to eq('bytes')
        expect(response.headers['Content-Range']).to be_nil
        expect(response.headers['X-Error-Type']).to be_present
        expect(response.headers['X-Error-Message']).to include('sample_rate parameter')
        expect(response.headers['Content-Disposition']).to be_nil
        expect(response.headers['Content-Transfer-Encoding']).to be_nil
      end
    end

    it 'does not advertise audio in an invalid-rate JSON error' do
      request_media('json', params: { sample_rate: 1234 })
      expect_error(:unprocessable_content, a_string_including('sample_rate parameter'))
      expect(response.body).not_to include('"available":{"audio"')
    end
  end
end
