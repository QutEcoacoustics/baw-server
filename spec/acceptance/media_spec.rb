require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'
require 'helpers/resque_helper'
# For some reason this patch is not loaded and I can't work out why
require (File.expand_path(__FILE__ + "/../../../lib/patches/mime_type.rb"))

# https://github.com/zipmark/rspec_api_documentation
resource 'Media' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy





  after(:each) do
    remove_media_dirs
  end

  # prepare ids needed for paths in requests below
  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:audio_recording_id) { audio_recording.id }

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_size_bytes) { 822281 }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_original) {
    puts "audio original path"
    puts BawWorkers::Settings.paths.original_audios
    ao = BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios)
  }
  let(:audio_cache) { BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios) }
  let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms) }
  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs) }

  ################################
  # MEDIA GET - long path
  ################################
  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { admin_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as admin)', :ok, {expected_json_path: 'data/recording/channel_count'})
  end

  get 'audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { owner_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as owner)', :ok, {expected_json_path: 'data/recording/channel_count'})
  end

  get 'audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as writer)', :ok, {expected_json_path: 'data/recording/channel_count'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as reader)', :ok, {expected_json_path: 'data/recording/channel_count'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request_options(:get, 'MEDIA (invalid format (mp4), as reader)', :not_acceptable, {expected_json_path: 'meta/error/info/available_formats/audio/0/'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { no_access_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { invalid_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # MEDIA GET - shallow path
  ################################

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { admin_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as admin with shallow path)', :ok, {expected_json_path: 'data/common_parameters/start_offset'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as writer with shallow path)', :ok, {expected_json_path: 'data/common_parameters/start_offset'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as reader with shallow path)', :ok, {expected_json_path: 'data/common_parameters/start_offset'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { no_access_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as no access user with shallow path)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { invalid_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (with invalid token with shallow path)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as anonymous user with shallow path)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request_options(:get, 'MEDIA (invalid format (mp4), as reader with shallow path)', :not_acceptable, {expected_json_path: 'meta/error/info/available_formats'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'zjfyrdnd' }
    # can't respond with the format requested
    standard_request_options(:get, 'MEDIA (invalid format (zjfyrdnd), as reader with shallow path)', :not_acceptable, {expected_json_path: 'meta/error/info/available_formats'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true

    let(:raw_post) { params.to_json }

    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    example 'MEDIA (as reader) checking default json format - 200', document: true do
      do_request
      expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

      json_paths = [
          'meta',
          'meta/status',
          'meta/message',
          'data',
          'data/recording',
          'data/recording/id',
          'data/recording/uuid',
          'data/recording/recorded_date',
          'data/recording/duration_seconds',
          'data/recording/sample_rate_hertz',
          'data/recording/channel_count',
          'data/recording/media_type',
          'data/common_parameters',
          'data/common_parameters/start_offset',
          'data/common_parameters/end_offset',
          'data/common_parameters/audio_event_id',
          'data/common_parameters/channel',
          'data/common_parameters/sample_rate',
          'data/available',
          'data/available/audio',
          'data/available/audio/mp3',
          'data/available/audio/mp3/media_type',
          'data/available/audio/mp3/extension',
          'data/available/audio/mp3/url',
          'data/available/audio/webm',
          'data/available/audio/webm/media_type',
          'data/available/audio/webm/extension',
          'data/available/audio/webm/url',
          'data/available/audio/ogg',
          'data/available/audio/ogg/media_type',
          'data/available/audio/ogg/extension',
          'data/available/audio/ogg/url',
          'data/available/audio/flac',
          'data/available/audio/flac/media_type',
          'data/available/audio/flac/extension',
          'data/available/audio/flac/url',
          'data/available/audio/wav',
          'data/available/audio/wav/media_type',
          'data/available/audio/wav/extension',
          'data/available/audio/wav/url',
          'data/available/image',
          'data/available/image/png',
          'data/available/image/png/window_size',
          'data/available/image/png/window_function',
          'data/available/image/png/colour',
          'data/available/image/png/ppms',
          'data/available/image/png/media_type',
          'data/available/image/png/extension',
          'data/available/image/png/url',
          'data/available/text',
          'data/available/text/json',
          'data/available/text/json/media_type',
          'data/available/text/json/extension',
          'data/available/text/json/url',
          'data/options',
          'data/options/channels',
          'data/options/audio',
          'data/options/audio/duration_max',
          'data/options/audio/duration_min',
          'data/options/audio/formats',
          # there are 5 valid sample formats, but just check the first and last
          'data/options/audio/formats/0/name',
          'data/options/audio/formats/0/valid_sample_rates',
          'data/options/audio/formats/4/name',
          'data/options/audio/formats/4/valid_sample_rates',
          'data/options/image',
          'data/options/image/spectrogram',
          'data/options/image/spectrogram/duration_max',
          'data/options/image/spectrogram/duration_min',
          'data/options/image/spectrogram/formats',
          'data/options/image/spectrogram/window_sizes',
          'data/options/image/spectrogram/window_functions',
          'data/options/image/spectrogram/colours',
          'data/options/image/spectrogram/colours/g',
          'data/options/image/spectrogram/valid_sample_rates',
          'data/options/text',
          'data/options/text/formats',
      ]

      # check that audio formats options has the right number of entries
      unexpected_json_paths = [
          'data/options/audio/formats/5/'
      ]

      check_hash_matches(json_paths, response_body, unexpected_json_paths)

      mp3_valid_sample_rates = (JsonSpec::Helpers::parse_json(response_body)["data"]["options"]["audio"]["formats"].select { | vsr | vsr["name"] == 'mp3'})[0]["valid_sample_rates"]
      wav_valid_sample_rates = (JsonSpec::Helpers::parse_json(response_body)["data"]["options"]["audio"]["formats"].select { | vsr | vsr["name"] == 'wav'})[0]["valid_sample_rates"]

      expect(mp3_valid_sample_rates).to eq([8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000])
      expect(wav_valid_sample_rates).to eq([8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000, 96000])

    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format?sample_rate=:sample_rate' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true

    let(:raw_post) { params.to_json }

    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:sample_rate) { 96000 }

    example 'MEDIA (as reader)json 96000hz', document: true do
      do_request
      expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

      # no data/options when modified params are supplied

      json_paths = [
          'meta',
          'meta/status',
          'meta/message',
          'data',
          'data/recording',
          'data/recording/id',
          'data/recording/uuid',
          'data/recording/recorded_date',
          'data/recording/duration_seconds',
          'data/recording/sample_rate_hertz',
          'data/recording/channel_count',
          'data/recording/media_type',
          'data/common_parameters',
          'data/common_parameters/start_offset',
          'data/common_parameters/end_offset',
          'data/common_parameters/audio_event_id',
          'data/common_parameters/channel',
          'data/common_parameters/sample_rate',
          'data/available',
          'data/available/audio',
          'data/available/audio/webm',
          'data/available/audio/webm/media_type',
          'data/available/audio/webm/extension',
          'data/available/audio/webm/url',
          'data/available/audio/ogg',
          'data/available/audio/ogg/media_type',
          'data/available/audio/ogg/extension',
          'data/available/audio/ogg/url',
          'data/available/audio/flac',
          'data/available/audio/flac/media_type',
          'data/available/audio/flac/extension',
          'data/available/audio/flac/url',
          'data/available/audio/wav',
          'data/available/audio/wav/media_type',
          'data/available/audio/wav/extension',
          'data/available/audio/wav/url',
          'data/available/image',
          'data/available/image/png',
          'data/available/image/png/window_size',
          'data/available/image/png/window_function',
          'data/available/image/png/colour',
          'data/available/image/png/ppms',
          'data/available/image/png/media_type',
          'data/available/image/png/extension',
          'data/available/image/png/url',
          'data/available/text',
          'data/available/text/json',
          'data/available/text/json/media_type',
          'data/available/text/json/extension',
          'data/available/text/json/url'
      ]

      check_hash_matches(json_paths, response_body)

    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    let(:start_offset) { '1' }
    let(:end_offset) { '2' }
    let(:sample_rate) { '11025' }

    example 'MEDIA (as reader) checking modified json format - 200', document: true do
      do_request
      expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

      json_paths = [
          'meta',
          'meta/status',
          'meta/message',
          'data',
          'data/recording',
          'data/recording/id',
          'data/recording/uuid',
          'data/recording/recorded_date',
          'data/recording/duration_seconds',
          'data/recording/sample_rate_hertz',
          'data/recording/channel_count',
          'data/recording/media_type',
          'data/common_parameters',
          'data/common_parameters/start_offset',
          'data/common_parameters/end_offset',
          'data/common_parameters/audio_event_id',
          'data/common_parameters/channel',
          'data/common_parameters/sample_rate',
          'data/available',
          'data/available/audio',
          'data/available/audio/mp3',
          'data/available/audio/mp3/media_type',
          'data/available/audio/mp3/extension',
          'data/available/audio/mp3/url',
          'data/available/audio/webm',
          'data/available/audio/webm/media_type',
          'data/available/audio/webm/extension',
          'data/available/audio/webm/url',
          'data/available/audio/ogg',
          'data/available/audio/ogg/media_type',
          'data/available/audio/ogg/extension',
          'data/available/audio/ogg/url',
          'data/available/audio/flac',
          'data/available/audio/flac/media_type',
          'data/available/audio/flac/extension',
          'data/available/audio/flac/url',
          'data/available/audio/wav',
          'data/available/audio/wav/media_type',
          'data/available/audio/wav/extension',
          'data/available/audio/wav/url',
          'data/available/image',
          'data/available/image/png',
          'data/available/image/png/window_size',
          'data/available/image/png/window_function',
          'data/available/image/png/colour',
          'data/available/image/png/ppms',
          'data/available/image/png/media_type',
          'data/available/image/png/extension',
          'data/available/image/png/url',
          'data/available/text',
          'data/available/text/json',
          'data/available/text/json/media_type',
          'data/available/text/json/extension',
          'data/available/text/json/url'
      ]

      check_hash_matches(json_paths, response_body)

    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    let(:start_offset) { '1' }
    let(:end_offset) { '2' }
    let(:sample_rate) { '11025' }

    example 'MEDIA (as reader) checking modified json format - 200', document: true do
      do_request
      expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"
      expect(response_body).to include('audio/mpeg')
      expect(response_body).not_to include('audio/mp3')

      # not sure how to test that duration_seconds returns an unquoted number
      #parsed = JsonSpec::Helpers::parse_json(response_body)
      #expect(parsed.data.recording.duration_seconds.class).to be_a(BigDecimal)
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp3' }

    media_request_options(
        :get,
        'MEDIA (audio get request mp3 as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/mpeg'
        })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'wav' }

    media_request_options(
        :get,
        'MEDIA (audio get request wav as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/wav'
        })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'ogg' }

    media_request_options(
        :get,
        'MEDIA (audio get request ogg as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/ogg'
        })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'webm' }

    media_request_options(
        :get,
        'MEDIA (audio get request webm as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/webm'
        })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'flac' }

    media_request_options(
        :get,
        'MEDIA (audio get request flac as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/x-flac'
        })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'png' }

    media_request_options(
        :get,
        'MEDIA (spectrogram get request as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'image/png'
        })
  end

  describe 'requesting non-standard sample rates' do


    let(:audio_file_mono2) {
      {
          source: File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-stereo-7777hz.ogg'),
          media_type: Mime::Type.lookup('audio/ogg'),
          sample_rate: 7777,
          channels: 2,
          duration_seconds: 70
      }
    }

    before(:each) do
        audio_recording.update_attribute(:sample_rate_hertz, 7777)
        # create_media_options creates the options for testing, but also copies the actual file
        # so we need to call it here again to copy the correct file
        create_media_options audio_recording, audio_file_mono2[:source]
    end

    # non-standard sample rate that is the original sample rate
    get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'wav' }
      let(:sample_rate) { '7777' }

      media_request_options(
          :get,
          'MEDIA (audio get request wav with non-standard original sample rate as reader)',
          :ok,
          {
              dont_copy_test_audio: true,
              expected_response_content_type: 'audio/wav'
          }
      )
    end

    # non-standard sample rate should fail if it is not the original sample rate
    get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'wav' }
      let(:sample_rate) { '7776' }

      media_request_options(
          :get,
          'MEDIA (audio get request wav with non-standard and non-original sample rate as reader)',
          :unprocessable_entity,
          {
              expected_response_content_type: 'audio/wav',
              expected_response_has_content: false,
              expected_headers: []
          }
      )
    end

    # non-standard sample rate should fail for mp3 even if it is the original sample rate
    get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'mp3' }
      let(:sample_rate) { '7777' }

      media_request_options(
          :get,
          'MEDIA (audio get request mp3 with non-standard original sample rate as reader)',
          :unprocessable_entity,
          {
              expected_response_content_type: 'audio/mpeg',
              expected_response_has_content: false,
              expected_headers: []
          }
      )
    end


    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'json' }
      parameter :sample_rate
      let(:sample_rate) { '1234' }
      standard_request_options(
          :get,
          'MEDIA (json), as reader with non-standard non-original sample rate)',
          :unprocessable_entity,
          {
              expected_response_content_type: 'application/json',
              expected_json_path: ['meta/error'],
              invalid_content: ['"available":{"audio"']
          }
      )
    end

    get '/audio_recordings/:audio_recording_id/media.:format?sample_rate=:sample_rate' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true
      let(:authentication_token) { reader_token }
      let(:format) { 'json' }
      let(:sample_rate) { 7777 }

      let(:raw_post) { params.to_json }


      example 'MEDIA (json), as reader with non-standard sample rate which is original sample rate', document: false do
        do_request
        expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

        # no data/options when modified params are supplied

        json_paths = [
            'meta',
            'meta/status',
            'meta/message',
            'data',
            'data/recording',
            'data/recording/id',
            'data/recording/uuid',
            'data/recording/recorded_date',
            'data/recording/duration_seconds',
            'data/recording/sample_rate_hertz',
            'data/recording/channel_count',
            'data/recording/media_type',
            'data/common_parameters',
            'data/common_parameters/start_offset',
            'data/common_parameters/end_offset',
            'data/common_parameters/audio_event_id',
            'data/common_parameters/channel',
            'data/common_parameters/sample_rate',
            'data/available',
            'data/available/audio',
            'data/available/audio/webm',
            'data/available/audio/webm/media_type',
            'data/available/audio/webm/extension',
            'data/available/audio/webm/url',
            'data/available/audio/ogg',
            'data/available/audio/ogg/media_type',
            'data/available/audio/ogg/extension',
            'data/available/audio/ogg/url',
            'data/available/audio/flac',
            'data/available/audio/flac/media_type',
            'data/available/audio/flac/extension',
            'data/available/audio/flac/url',
            'data/available/audio/wav',
            'data/available/audio/wav/media_type',
            'data/available/audio/wav/extension',
            'data/available/audio/wav/url',
            'data/available/image',
            'data/available/image/png',
            'data/available/image/png/window_size',
            'data/available/image/png/window_function',
            'data/available/image/png/colour',
            'data/available/image/png/ppms',
            'data/available/image/png/media_type',
            'data/available/image/png/extension',
            'data/available/image/png/url',
            'data/available/text',
            'data/available/text/json',
            'data/available/text/json/media_type',
            'data/available/text/json/extension',
            'data/available/text/json/url'
        ]

        check_hash_matches(json_paths, response_body)

      end
    end


    get '/audio_recordings/:audio_recording_id/media.:format' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
      parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true

      let(:raw_post) { params.to_json }
      let(:authentication_token) { reader_token }
      let(:format) { 'json' }

      example 'MEDIA (as reader) checking json valid sample rates for audio recording with non-standard original sample rate - 200', document: true do
        do_request
        expect(status).to eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

        mp3_valid_sample_rates = (JsonSpec::Helpers::parse_json(response_body)["data"]["options"]["audio"]["formats"].select { | vsr | vsr["name"] == 'mp3'})[0]["valid_sample_rates"]
        wav_valid_sample_rates = (JsonSpec::Helpers::parse_json(response_body)["data"]["options"]["audio"]["formats"].select { | vsr | vsr["name"] == 'wav'})[0]["valid_sample_rates"]

        expect(mp3_valid_sample_rates).to eq([8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000])
        expect(wav_valid_sample_rates).to eq([8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000, 96000, 7777])

      end
    end

  end

  # head requests

  head '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    media_request_options(
        :head,
        'MEDIA (json head request as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'application/json',
            expected_response_has_content: false
        })
  end

  head '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp3' }

    media_request_options(
        :head,
        'MEDIA (audio head request mp3 as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'audio/mpeg',
            expected_response_has_content: false
        })
  end

  head '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'png' }

    media_request_options(
        :head,
        'MEDIA (spectrogram head request as reader with shallow path)',
        :ok,
        {
            document: document_media_requests,
            expected_response_content_type: 'image/png',
            expected_response_has_content: false
        })
  end

  # test audio_event_id

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { audio_event.id }
    let(:start_offset) { 4 }
    let(:end_offset) { 7 }

    before do
      audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
    end

    standard_request_options(:get, 'MEDIA (as reader with shallow path, valid audio event request offsets with read access to audio recording)', :ok, {expected_json_path: 'data/recording/recorded_date'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { 4 }
    let(:end_offset) { 7 }

    let(:audio_recording_id) {
      project = Creation::Common.create_project(no_access_user)
      site = Creation::Common.create_site(no_access_user, project)
      audio_recording = Creation::Common.create_audio_recording(no_access_user, no_access_user, site)
      audio_recording.id
    }

    let(:audio_event_id) {
      audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
      audio_event.id
    }

    standard_request_options(:get, 'MEDIA (as reader with shallow path, valid audio event request offsets with no access to audio recording)', :ok, {expected_json_path: 'data/recording/recorded_date'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { audio_event.id }
    let(:start_offset) { 120 }
    let(:end_offset) { 150 }

    before do
      audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 0, end_time_seconds: 10, is_reference: true)
    end

    standard_request_options(:get, 'MEDIA (as reader with shallow path, invalid audio event request offsets)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { 20 }
    let(:end_offset) { 23 }
    let(:audio_recording_id) {
      project = Creation::Common.create_project(no_access_user)
      site = Creation::Common.create_site(no_access_user, project)
      audio_recording = Creation::Common.create_audio_recording(no_access_user, no_access_user, site)
      audio_recording.id
    }
    let(:audio_event_id) {
      audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 21, end_time_seconds: 22, is_reference: false)
      audio_event.id
    }

    standard_request_options(:get, 'MEDIA (as reader with shallow path, not a reference audio event)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { 10 }
    let(:end_offset) { 13 }

    let(:audio_recording_id) {
      project = Creation::Common.create_project(no_access_user)
      site = Creation::Common.create_site(no_access_user, project)
      audio_recording = Creation::Common.create_audio_recording(no_access_user, no_access_user, site)
      audio_recording.id
    }

    let(:audio_event_id) { audio_event.id }
    let!(:other_audio_event_id) {# so there is an additional audio event
      audio_event = FactoryGirl.create(:audio_event,
                                       audio_recording_id: audio_recording_id,
                                       start_time_seconds: 11, end_time_seconds: 12,
                                       is_reference: true)
      audio_event.id
    }

    standard_request_options(:get, 'MEDIA (as reader with shallow path, audio event request not related to audio recording)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  #
  # Ensure parameter checks are working
  #

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { 'number' }
    standard_request_options(:get, 'MEDIA (as reader invalid start_offset)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'start_offset parameter must be a decimal number'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { 'number' }
    standard_request_options(:get, 'MEDIA (as reader invalid end_offset)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'end_offset parameter must be a decimal number'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { (audio_recording.duration_seconds + 1).to_s }
    standard_request_options(:get, 'MEDIA (as reader end_offset past original duration)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'smaller than or equal to the duration of the audio recording'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { '0' }
    standard_request_options(:get, 'MEDIA (as reader end_offset too small)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'must be greater than 0.'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { audio_recording.duration_seconds.to_s }
    standard_request_options(:get, 'MEDIA (as reader start_offset past original duration)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'smaller than the duration of the audio recording'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { '-1' }
    standard_request_options(:get, 'MEDIA (as reader start_offset smaller than 0)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'greater than or equal to 0'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { '9' }
    let(:end_offset) { '8' }
    standard_request_options(:get, 'MEDIA (as reader start_offset larger than end_offset)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'smaller than end_offset'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&window_size=:window_size' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:window_size) { 'number' }
    standard_request_options(:get, 'MEDIA (as reader invalid window_size)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'window_size parameter'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&window_function=:window_function' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:window_function) { 'number' }
    standard_request_options(:get, 'MEDIA (as reader invalid window_function)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'window_function parameter'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:sample_rate) { '22' }
    standard_request_options(:get, 'MEDIA (as reader invalid sample_rate)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'sample_rate parameter'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&channel=:channel' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:channel) { (audio_recording.channels + 1).to_s }
    standard_request_options(:get, 'MEDIA (as reader invalid channel)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'channel parameter'})
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&colour=:colour' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:colour) { 'h' }
    standard_request_options(:get, 'MEDIA (as reader invalid colour)', :unprocessable_entity,
                             {expected_json_path: 'meta/error/details', response_body_content: 'colour parameter'})
  end

  # ensure integer parameters are checked
  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=22050user_token=ANAUTHTOKEN' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as reader invalid sample rate)', :unprocessable_entity,
                             {
                                 expected_json_path: 'meta/error/details',
                                 response_body_content: 'The request could not be understood: sample_rate parameter (22050user_token=ANAUTHTOKEN) must be an integer'
                             })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&window_size=512user_token=ANAUTHTOKEN' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as reader invalid window size)', :unprocessable_entity,
                             {
                                 expected_json_path: 'meta/error/details',
                                 response_body_content: 'The request could not be understood: window_size parameter (512user_token=ANAUTHTOKEN) must be valid'
                             })
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&channel=0user_token=ANAUTHTOKEN' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request_options(:get, 'MEDIA (as reader invalid sample rate)', :unprocessable_entity,
                             {
                                 expected_json_path: 'meta/error/details',
                                 response_body_content: 'The request could not be understood: channel parameter (0user_token=ANAUTHTOKEN) must be valid'
                             })
  end

  # test remote audio and spectrogram generation
  context 'remote media generation' do
    around(:each) do |example|
      Settings[:media_request_processor] = Settings::MEDIA_PROCESSOR_RESQUE
      stored = Settings.audio_tools_timeout_sec
      Settings[:audio_tools_timeout_sec] = 2
      example.run
      Settings[:media_request_processor] = Settings::MEDIA_PROCESSOR_LOCAL
      Settings[:audio_tools_timeout_sec] = stored
    end

    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'mp3' }

      example ':get MEDIA (audio get request mp3 as reader with shallow path process using resque)', document: document_media_requests do
        remove_media_dirs

        options = create_media_options(audio_recording, audio_file_mono)

        queue_name = Settings.actions.media.queue

        # do first request - this purposely fails,
        request1 = do_request

        # check response
        opts1 =
            {
                expected_status: :internal_server_error,
                expected_method: :get,
                expected_response_content_type: 'audio/mpeg',
                document: document_media_requests,
                expected_response_media_from_header: MediaPoll::HEADER_VALUE_RESPONSE_REMOTE,
                expected_response_has_content: false,
                expected_response_header_values_match: false,
                expected_response_header_values: {
                    'X-Error-Type' => 'Custom Errors/Audio Generation Error'
                }
            }

        opts1 = acceptance_checks_shared(request1, opts1)

        acceptance_checks_media(opts1.merge({audio_recording: options}))

        # store request that's in queue
        expect(Resque.size(queue_name)).to eq(1)

        # run emulated worker - this will process the single job in the queue
        # we're restricted to a single thread, so can't run request and worker at once (they both block)
        emulate_resque_worker(queue_name, false, true)

        # run a second request, which should use the cached file to complete the request
        request2 = do_request

        expect(Resque.size(queue_name)).to eq(0)

        # check response
        opts2 =
            {
                expected_status: :ok,
                expected_method: :get,
                expected_response_content_type: 'audio/mpeg',
                document: document_media_requests,
                expected_response_media_from_header: MediaPoll::HEADER_VALUE_RESPONSE_CACHE
            }

        opts2 = acceptance_checks_shared(request2, opts2)

        opts2.merge!({audio_recording: options})
        acceptance_checks_media(opts2)
      end
    end

  end

  context 'range request' do
    header 'Range', 'bytes=0-'

    get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'mp3' }

      media_request_options(
          :get,
          'MEDIA (audio get request mp3 as reader with shallow path using range request)',
          :partial_content,
          {
              document: document_media_requests,
              expected_response_content_type: 'audio/mpeg',
              is_range_request: true
          })
    end

    head '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'mp3' }

      media_request_options(
          :head,
          'MEDIA (audio get request mp3 as reader with shallow path using range request)',
          :partial_content,
          {
              document: document_media_requests,
              expected_response_content_type: 'audio/mpeg',
              is_range_request: true,
              expected_response_has_content: false
          })
    end
  end

  context 'content disposition format' do
    get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'wav' }


      media_request_options(
          :get,
          'MEDIA (audio get request wav as reader with shallow path)',
          :ok,
          {
              document: document_media_requests,
              expected_response_content_type: 'audio/wav',
              expected_partial_response_header_value: {
                  'Content-Disposition' => '20120326_070700_1_0.wav"'
              }
          })
    end
  end

  ################################
  # ORIGINAL
  ################################
  describe "original audio download" do

    let(:start_offset) { nil }
    let(:end_offset) { nil }

    before(:each) do
      # the standard media route only allows short recordings, purposely mock a long duration to make sure long
      # original recordings succeed.
      audio_recording.update_attribute(:duration_seconds, 3600) # one hour
      create_media_options(audio_recording, audio_file_mono)
    end

    after(:each) do
      remove_media_dirs
    end

    def full_file_result(context, opts)
      filename = context.audio_recording.canonical_filename
      opts.merge!({
          expected_response_content_type: context.audio_recording.media_type,
          expected_response_has_content: true,
          expected_response_header_values_match: false,
          expected_response_header_values: {
            'Content-Length' => context.audio_file_mono_size_bytes.to_s,
            'Content-Disposition' => "attachment; filename=\"#{filename}\"",
            'Digest' => 'SHA256=' + context.audio_recording.split_file_hash[1]
          },
          is_range_request: false
      })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { reader_token }

      standard_request_options(:get, 'ORIGINAL (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { writer_token }

      standard_request_options(:get, 'ORIGINAL (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { no_access_token }

      standard_request_options(:get, 'ORIGINAL (as no access)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { invalid_token }

      standard_request_options(:get, 'ORIGINAL (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { owner_token }

      standard_request_options(:get, 'ORIGINAL (as owner token)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { admin_token }

      standard_request_options(
          :get,
          'ORIGINAL (as admin token)',
          :ok,
          {},
          &proc { |context, opts|
            context.full_file_result(context, opts)
          })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { harvester_token }

      standard_request_options(
          :get,
          'ORIGINAL (as harvester token)',
          :ok,
          {},
          &proc { |context, opts|
            context.full_file_result(context, opts)
          })
    end

  end

end
