require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Media' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
    @admin_user = FactoryGirl.create(:admin)
  end

  after(:all) do
    remove_media_dirs(media_cacher)
  end

  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:site_id) { @write_permission.project.sites[0].id }
  let(:audio_recording_id) { @write_permission.project.sites[0].audio_recordings[0].id }
  let(:audio_recording) { @write_permission.project.sites[0].audio_recordings[0] }
  let(:audio_event) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0] }

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:media_cacher) { BawAudioTools::MediaCacher.new(Settings.paths.temp_files) }

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:invalid_token) { "Token token=\"blah blah blah\"" }

  ################################
  # MEDIA GET - long path
  ################################
  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { admin_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as admin)', 200, nil, true)
  end

  get 'audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as writer)', 200, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as reader)', 200, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request('MEDIA (invalid format (mp4), as reader)', 406, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { unconfirmed_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as unconfirmed user)', 403, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { invalid_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as invalid token)', 401, nil, true)
  end

  ################################
  # MEDIA GET - shallow path
  ################################

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { admin_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as admin with shallow path)', 200, 'data/common_parameters/start_offset', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as writer with shallow path)', 200, 'data/common_parameters/start_offset', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as reader with shallow path)', 200, 'data/common_parameters/start_offset', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { unconfirmed_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as unconfirmed with shallow path)', 403, 'meta/error/links/confirm your account', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { invalid_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as invalid with shallow path)', 401, 'meta/error/links/sign in', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request('MEDIA (invalid format (mp4), as reader with shallow path)', 406, 'meta/error/available_formats', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'zjfyrdnd' }
    # can't respond with the format requested
    standard_request('MEDIA (invalid format (zjfyrdnd), as reader with shallow path)', 406, 'meta/error/available_formats', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true

    let(:raw_post) { params.to_json }

    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    example 'MEDIA (as reader) checking default json format - 200', document: true do
      do_request
      status.should eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

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
          'data/options/valid_sample_rates',
          'data/options/channels',
          'data/options/audio',
          'data/options/audio/duration_max',
          'data/options/audio/duration_min',
          'data/options/audio/formats',
          'data/options/image',
          'data/options/image/spectrogram',
          'data/options/image/spectrogram/duration_max',
          'data/options/image/spectrogram/duration_min',
          'data/options/image/spectrogram/formats',
          'data/options/image/spectrogram/window_sizes',
          'data/options/image/spectrogram/window_functions',
          'data/options/image/spectrogram/colours',
          'data/options/image/spectrogram/colours/g',
          'data/options/text',
          'data/options/text/formats',
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
      status.should eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

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
      status.should eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

      # not sure how to test that duration_seconds returns an unquoted number
      #parsed = JsonSpec::Helpers::parse_json(response_body)
      #expect(parsed.data.recording.duration_seconds.class).to be_a(BigDecimal)
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp3' }
    example 'MEDIA (audio get request mp3 as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'audio/mp3')
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'wav' }
    example 'MEDIA (audio get request wav as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'audio/wav')
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'ogg' }
    example 'MEDIA (audio get request ogg as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'audio/ogg')
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'webm' }
    example 'MEDIA (audio get request webm as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'audio/webm')
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'flac' }
    example 'MEDIA (audio get request flac as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'audio/x-flac')
    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'png' }
    example 'MEDIA (spectrogram get request as reader with shallow path) - 200', document: document_media_requests do
      using_original_audio(audio_recording, 'image/png', false)
    end
  end

  # head requests

  head '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    # don't document because it returns binary data that can't be json encoded
    example 'MEDIA (json head request as reader with shallow path) - 200', document: true do
      using_original_audio(audio_recording, 'application/json', false, true, true)
    end
  end

  head '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp3' }
    example 'MEDIA (audio head request mp3 as reader with shallow path) - 200', document: true do
      using_original_audio(audio_recording, 'audio/mp3', false, false, true)
    end
  end

  head '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'png' }
    example 'MEDIA (spectrogram head request as reader with shallow path) - 200', document: true do
      using_original_audio(audio_recording, 'image/png', false, true, true)
    end
  end

  # test audio_event_id

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { @audio_event.id }
    let(:start_offset) { 4 }
    let(:end_offset) { 7 }

    before do
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
    end

    standard_request('MEDIA (as reader with shallow path, valid audio event request offsets with read access to audio recording)', 200, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { @audio_event.id }
    let(:start_offset) { 4 }
    let(:end_offset) { 7 }
    let(:audio_recording_id) { @other_audio_recording_id }

    before do
      other_permissions = FactoryGirl.create(:write_permission)
      @other_audio_recording_id = other_permissions.project.sites[0].audio_recordings[0].id
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: @other_audio_recording_id, start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
    end

    standard_request('MEDIA (as reader with shallow path, valid audio event request offsets with no access to audio recording)', 200, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { @audio_event.id }
    let(:start_offset) { 120 }
    let(:end_offset) { 150 }

    before do
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: audio_recording_id, start_time_seconds: 0, end_time_seconds: 10, is_reference: true)
    end

    standard_request('MEDIA (as reader with shallow path, invalid audio event request offsets)', 403, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { @audio_event.id }
    let(:start_offset) { 20 }
    let(:end_offset) { 23 }
    let(:audio_recording_id) { @other_audio_recording_id }

    before do
      other_permissions = FactoryGirl.create(:write_permission)
      @other_audio_recording_id = other_permissions.project.sites[0].audio_recordings[0].id
      # note that this audio event is not a reference audio event
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: @other_audio_recording_id, start_time_seconds: 21, end_time_seconds: 22, is_reference: false)
    end

    standard_request('MEDIA (as reader with shallow path, not a reference audio event)', 403, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format?audio_event_id=:audio_event_id&start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:audio_event_id) { audio_event.id } # pre-existing audio event
    let(:start_offset) { 10 }
    let(:end_offset) { 13 }
    let(:audio_recording_id) { @other_audio_recording_id }

    before do
      other_permissions = FactoryGirl.create(:write_permission)
      @other_audio_recording_id = other_permissions.project.sites[0].audio_recordings[0].id
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: @other_audio_recording_id, start_time_seconds: 11, end_time_seconds: 12, is_reference: true)
    end

    standard_request('MEDIA (as reader with shallow path, audio event request not related to audio recording)', 403, 'meta/error/links/request permissions', true)
  end

  # test audio_recording_catalogue api

  get '/audio_recording_catalogue' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    standard_request('CATALOGUE (as reader)', 200, '0/count', true)
  end

  get '/audio_recording_catalogue?projectId=99999998888' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    standard_request('CATALOGUE (as reader with invalid project)', 404, 'meta/error/details', true)
  end

  get '/audio_recording_catalogue?siteId=9999998888' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    standard_request('CATALOGUE (as reader with invalid site)', 404, 'meta/error/details', true)
  end

  get '/audio_recording_catalogue?projectId=:project_id&siteId=:site_id' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }

    standard_request('CATALOGUE (as reader restricted to site)', 200, '0/count', true)
  end

  #
  # Ensure parameter checks are working
  #

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { 'number' }
    standard_request('MEDIA (as reader invalid start_offset)', 422,
                     'meta/error/details', true, 'start_offset parameter must be a decimal number')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { 'number' }
    standard_request('MEDIA (as reader invalid end_offset)', 422,
                     'meta/error/details', true, 'end_offset parameter must be a decimal number')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { (audio_recording.duration_seconds + 1).to_s }
    standard_request('MEDIA (as reader end_offset past original duration)', 422,
                     'meta/error/details', true, 'smaller than or equal to the duration of the audio recording')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:end_offset) { '0' }
    standard_request('MEDIA (as reader end_offset too small)', 422,
                     'meta/error/details', true, 'must be greater than 0.')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { audio_recording.duration_seconds.to_s }
    standard_request('MEDIA (as reader start_offset past original duration)', 422,
                     'meta/error/details', true, 'smaller than the duration of the audio recording')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { '-1' }
    standard_request('MEDIA (as reader start_offset smaller than 0)', 422,
                     'meta/error/details', true, 'greater than or equal to 0')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:start_offset) { '9' }
    let(:end_offset) { '8' }
    standard_request('MEDIA (as reader start_offset larger than end_offset)', 422,
                     'meta/error/details', true, 'smaller than end_offset')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&window_size=:window_size' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:window_size) { 'number' }
    standard_request('MEDIA (as reader invalid window_size)', 422,
                     'meta/error/details', 'window_size parameter')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&window_function=:window_function' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:window_function) { 'number' }
    standard_request('MEDIA (as reader invalid window_function)', 422,
                     'meta/error/details', 'window_function parameter')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&sample_rate=:sample_rate' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:sample_rate) { '22' }
    standard_request('MEDIA (as reader invalid sample_rate)', 422,
                     'meta/error/details', 'sample_rate parameter')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&channel=:channel' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:channel) { (audio_recording.channels + 1).to_s }
    standard_request('MEDIA (as reader invalid channel)', 422,
                     'meta/error/details', 'channel parameter')
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=:start_offset&end_offset=:end_offset&colour=:colour' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    let(:colour) { 'h' }
    standard_request('MEDIA (as reader invalid colour)', 422,
                     'meta/error/details', 'colour parameter')
  end

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

      example 'MEDIA (audio get request mp3 as reader with shallow path) - 200', document: document_media_requests do
        remove_media_dirs(media_cacher)

        options = create_media_options(audio_recording)

        queue_name = Settings.resque.queues.media.to_sym

        # do first request - this purposely fails,
        # we're restricted to a single thread, so can't run request and worker at once (they both block)
        expect {
          do_request
        }.to raise_error(RuntimeError, /Took longer than 2 seconds for resque to fulfil media request/)

        # store request that's in queue
        expect(Resque.size(queue_name)).to eq(1)

        # run emulated worker - this will process the single job in the queue
        emulate_resque_worker(queue_name, false, true)

        # run a second request, which should use the cached file to complete the request
        request = do_request

        # assertions
        media_type = 'audio/mp3'
        validate_media_response(media_type)
        using_original_audio_custom(options, request, audio_recording, media_type)
      end
    end

  end
 
  context 'range request' do
    header 'Range', 'bytes=0-'

    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      let(:authentication_token) { reader_token }
      let(:format) { 'mp3' }
      example 'MEDIA (audio get request mp3 as reader with shallow path using range request) - 200', document: document_media_requests do
        using_original_audio(audio_recording, 'audio/mp3')

        expect(response_headers).to include('Accept-Ranges')
        expect(response_headers['Accept-Ranges']).to eq('bytes')

        expect(response_headers).to include('Content-Range')
        expect(response_headers['Content-Range']).to include('bytes 0-')

        expect(response_headers).to include('Content-Length')
        expect(response_headers['Content-Length']).to_not be_blank

        expect(response_headers).to include('X-Media-Response-From')
        expect(response_headers['X-Media-Response-From']).to eq('Generated Locally')

        expect(response_headers).to include('X-Media-Response-Start')
      end
    end
  end

end
