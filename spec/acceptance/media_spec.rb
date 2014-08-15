require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def standard_media_parameters

  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

  parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true
  parameter :start_offset, 'Start time of the audio segment in seconds'
  parameter :end_offset, 'End time of the audio segment in seconds'

  let(:start_offset) { '1' }
  let(:end_offset) { '2' }

  let(:raw_post) { params.to_json }
end

def check_common_request_items(audio_recording, content_type, check_accept_header = true)
  options = {}
  options[:datetime] = audio_recording.recorded_date
  options[:original_format] = File.extname(audio_recording.original_file_name) unless audio_recording.original_file_name.blank?
  options[:original_format] = '.' + Mime::Type.lookup(audio_recording.media_type).to_sym.to_s if options[:original_format].blank?
  options[:datetime_with_offset] = audio_recording.recorded_date
  options[:uuid] = audio_recording.uuid
  options[:id] = audio_recording.id
  options[:start_offset] = start_offset unless start_offset.blank?
  options[:end_offset] = end_offset unless end_offset.blank?

  original_file_names = media_cacher.original_audio_file_names(options)
  original_possible_paths = original_file_names.map { |source_file| media_cacher.cache.possible_storage_paths(media_cacher.cache.original_audio, source_file) }.flatten

  FileUtils.mkpath File.dirname(original_possible_paths.first)
  FileUtils.cp audio_file_mono, original_possible_paths.first

  request = do_request
  status.should eq(200), "expected status 200 but was #{status}. Response body was #{response_body}"
  response_headers['Content-Type'].should include(content_type)
  response_headers['Accept-Ranges'].should eq('bytes') if check_accept_header

  response_headers['Content-Transfer-Encoding'].should eq('binary') unless content_type == 'application/json'
  response_headers['Content-Transfer-Encoding'].should be_nil if content_type == 'application/json'

  response_headers['Content-Disposition'].should start_with('inline; filename=') unless content_type == 'application/json'
  response_headers['Content-Disposition'].should be_nil if content_type == 'application/json'

  [options, request]
end

def using_original_audio(audio_recording, content_type, check_accept_header = true, check_content_length = true, expected_head_request = false)

  options, request = check_common_request_items(audio_recording, content_type, check_accept_header)

  is_image = response_headers['Content-Type'].include? 'image'
  default_spectrogram = Settings.cached_spectrogram_defaults

  is_audio = response_headers['Content-Type'].include? 'audio'
  default_audio = Settings.cached_audio_defaults

  # !! - forces the boolean context, but returns the proper boolean value
  is_documentation_run = !!(ENV['GENERATE_DOC'])

  actual_head_request = !is_documentation_run && !request.blank? && !request[0].blank? && request[0][:request_method] == 'HEAD'

  # assert
  if actual_head_request || expected_head_request
    response_body.size.should eq(0)
    if is_image
      options[:format] = default_spectrogram.extension
      options[:channel] = default_spectrogram.channel.to_i
      options[:sample_rate] = default_spectrogram.sample_rate.to_i
      options[:window] = default_spectrogram.window.to_i
      options[:colour] = default_spectrogram.colour.to_s
      cache_spectrogram_file = media_cacher.cached_spectrogram_file_name(options)
      cache_spectrogram_possible_paths = media_cacher.cache.possible_storage_paths(media_cacher.cache.cache_spectrogram, cache_spectrogram_file)
      response_headers['Content-Length'].to_i.should eq(File.size(cache_spectrogram_possible_paths.first)) if check_content_length
    elsif is_audio
      options[:format] = default_audio.extension
      options[:channel] = default_audio.channel.to_i
      options[:sample_rate] = default_audio.sample_rate.to_i
      cache_audio_file = media_cacher.cached_audio_file_name(options)
      cache_audio_possible_paths = media_cacher.cache.possible_storage_paths(media_cacher.cache.cache_audio, cache_audio_file)
      response_headers['Content-Length'].to_i.should eq(File.size(cache_audio_possible_paths.first)) if check_content_length
    elsif response_headers['Content-Type'].include? 'application/json'
      response_headers['Content-Length'].to_i.should be > 0
      # TODO: files should not exist?
    else
      fail "Unrecognised content type: #{response_headers['Content-Type']}"
    end
  else
    begin
      temp_file = File.join(Settings.paths.temp_files, 'temp-media_controller_response')
      File.open(temp_file, 'wb') { |f| f.write(response_body) }
      response_headers['Content-Length'].to_i.should eq(File.size(temp_file))
    ensure
      File.delete temp_file if File.exists? temp_file
    end
  end
end

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
    FileUtils.rm_r media_cacher.cache.original_audio.storage_paths.first if Dir.exists? media_cacher.cache.original_audio.storage_paths.first
    FileUtils.rm_r media_cacher.cache.cache_audio.storage_paths.first if Dir.exists? media_cacher.cache.cache_audio.storage_paths.first
    FileUtils.rm_r media_cacher.cache.cache_spectrogram.storage_paths.first if Dir.exists? media_cacher.cache.cache_spectrogram.storage_paths.first
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
    standard_request('MEDIA (as admin with shallow path)', 200, 'common_parameters/start_offset', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as writer with shallow path)', 200,'common_parameters/start_offset', true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as reader with shallow path)', 200, 'common_parameters/start_offset', true)
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
          'recording',
          'recording/id',
          'recording/uuid',
          'recording/recorded_date',
          'recording/duration_seconds',
          'recording/sample_rate_hertz',
          'recording/channel_count',
          'recording/media_type',
          'common_parameters',
          'common_parameters/start_offset',
          'common_parameters/end_offset',
          'common_parameters/audio_event_id',
          'common_parameters/channel',
          'common_parameters/sample_rate',
          'available',
          'available/audio',
          'available/audio/mp3',
          'available/audio/mp3/media_type',
          'available/audio/mp3/extension',
          'available/audio/mp3/url',
          'available/audio/webm',
          'available/audio/webm/media_type',
          'available/audio/webm/extension',
          'available/audio/webm/url',
          'available/audio/ogg',
          'available/audio/ogg/media_type',
          'available/audio/ogg/extension',
          'available/audio/ogg/url',
          'available/audio/flac',
          'available/audio/flac/media_type',
          'available/audio/flac/extension',
          'available/audio/flac/url',
          'available/audio/wav',
          'available/audio/wav/media_type',
          'available/audio/wav/extension',
          'available/audio/wav/url',
          'available/image',
          'available/image/png',
          'available/image/png/window_size',
          'available/image/png/window_function',
          'available/image/png/colour',
          'available/image/png/ppms',
          'available/image/png/media_type',
          'available/image/png/extension',
          'available/image/png/url',
          'available/text',
          'available/text/json',
          'available/text/json/media_type',
          'available/text/json/extension',
          'available/text/json/url',
          'options',
          'options/valid_sample_rates',
          'options/channels',
          'options/audio',
          'options/audio/duration_max',
          'options/audio/duration_min',
          'options/audio/formats',
          'options/image',
          'options/image/spectrogram',
          'options/image/spectrogram/duration_max',
          'options/image/spectrogram/duration_min',
          'options/image/spectrogram/formats',
          'options/image/spectrogram/window_sizes',
          'options/image/spectrogram/window_functions',
          'options/image/spectrogram/colours',
          'options/image/spectrogram/colours/g',
          'options/text',
          'options/text/formats',
      ]

      check_hash_matches(json_paths, response_body)

    end
  end

  get '/audio_recordings/:audio_recording_id/media.:format?start_offset=1&end_offset=2&sample_rate=11025' do
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
          'recording',
          'recording/id',
          'recording/uuid',
          'recording/recorded_date',
          'recording/duration_seconds',
          'recording/sample_rate_hertz',
          'recording/channel_count',
          'recording/media_type',
          'common_parameters',
          'common_parameters/start_offset',
          'common_parameters/end_offset',
          'common_parameters/audio_event_id',
          'common_parameters/channel',
          'common_parameters/sample_rate',
          'available',
          'available/audio',
          'available/audio/mp3',
          'available/audio/mp3/media_type',
          'available/audio/mp3/extension',
          'available/audio/mp3/url',
          'available/audio/webm',
          'available/audio/webm/media_type',
          'available/audio/webm/extension',
          'available/audio/webm/url',
          'available/audio/ogg',
          'available/audio/ogg/media_type',
          'available/audio/ogg/extension',
          'available/audio/ogg/url',
          'available/audio/flac',
          'available/audio/flac/media_type',
          'available/audio/flac/extension',
          'available/audio/flac/url',
          'available/audio/wav',
          'available/audio/wav/media_type',
          'available/audio/wav/extension',
          'available/audio/wav/url',
          'available/image',
          'available/image/png',
          'available/image/png/window_size',
          'available/image/png/window_function',
          'available/image/png/colour',
          'available/image/png/ppms',
          'available/image/png/media_type',
          'available/image/png/extension',
          'available/image/png/url',
          'available/text',
          'available/text/json',
          'available/text/json/media_type',
          'available/text/json/extension',
          'available/text/json/url'
      ]

      check_hash_matches(json_paths, response_body)

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

end
