require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def parse_deep(parent, hash, remaining_to_match, not_included)
  hash.each { |key, value|

    new_parent = parent
    if parent.nil?
      new_parent = key
    else
      new_parent = parent + '/' + key
    end

    unless remaining_to_match.include?(new_parent)
      not_included.push(new_parent)
    end

    if value.is_a?(Hash)
      parse_deep(new_parent, value, remaining_to_match, not_included)
    end
  }
  not_included
end

def standard_media_parameters

  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

  parameter :format, 'Required format of the audio segment (defaults: json; alternatives: mp3|webm|ogg|wav|png). Use json if requesting metadata', required: true
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
  options[:start_offset] = start_offset
  options[:end_offset] = end_offset

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

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:media_cacher) { BawAudioTools::MediaCacher.new(Settings.paths.temp_files) }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }

  ################################
  # MEDIA GET
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { writer_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as writer)', 200, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as reader)', 200, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request('MEDIA (invalid format (mp4), as reader)', 415, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.:format' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { unconfirmed_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as unconfirmed user)', 403, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    standard_request('MEDIA (as reader with shallow path)', 200, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'mp4' }
    standard_request('MEDIA (invalid format (mp4), as reader with shallow path)', 415, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'zjfyrdnd' }
    standard_request('MEDIA (invalid format (zjfyrdnd), as reader with shallow path)', 415, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.:format' do
    standard_media_parameters
    let(:authentication_token) { reader_token }
    let(:format) { 'json' }
    example 'MEDIA (as reader) checking json format - 200', document: true do
      do_request
      status.should eq(200), "expected status #{200} but was #{status}. Response body was #{response_body}"

      json_paths = [
          'datetime',
          'original_format',
          'original_sample_rate',
          'start_offset',
          'end_offset',
          'uuid',
          'id',
          'format',
          'media_type',
          'available_audio_formats',
          'available_audio_formats/mp3',
          'available_audio_formats/mp3/channel',
          'available_audio_formats/mp3/sample_rate',
          'available_audio_formats/mp3/max_duration_seconds',
          'available_audio_formats/mp3/min_duration_seconds',
          'available_audio_formats/mp3/mime_type',
          'available_audio_formats/mp3/extension',
          'available_audio_formats/mp3/url',
          'available_audio_formats/mp3/start_offset',
          'available_audio_formats/mp3/end_offset',
          'available_audio_formats/webm',
          'available_audio_formats/webm/channel',
          'available_audio_formats/webm/sample_rate',
          'available_audio_formats/webm/max_duration_seconds',
          'available_audio_formats/webm/min_duration_seconds',
          'available_audio_formats/webm/mime_type',
          'available_audio_formats/webm/extension',
          'available_audio_formats/webm/url',
          'available_audio_formats/webm/start_offset',
          'available_audio_formats/webm/end_offset',
          'available_audio_formats/ogg',
          'available_audio_formats/ogg/channel',
          'available_audio_formats/ogg/sample_rate',
          'available_audio_formats/ogg/max_duration_seconds',
          'available_audio_formats/ogg/min_duration_seconds',
          'available_audio_formats/ogg/mime_type',
          'available_audio_formats/ogg/extension',
          'available_audio_formats/ogg/url',
          'available_audio_formats/ogg/start_offset',
          'available_audio_formats/ogg/end_offset',
          'available_audio_formats/flac',
          'available_audio_formats/flac/channel',
          'available_audio_formats/flac/sample_rate',
          'available_audio_formats/flac/max_duration_seconds',
          'available_audio_formats/flac/min_duration_seconds',
          'available_audio_formats/flac/mime_type',
          'available_audio_formats/flac/extension',
          'available_audio_formats/flac/url',
          'available_audio_formats/flac/start_offset',
          'available_audio_formats/flac/end_offset',
          'available_audio_formats/wav',
          'available_audio_formats/wav/channel',
          'available_audio_formats/wav/sample_rate',
          'available_audio_formats/wav/max_duration_seconds',
          'available_audio_formats/wav/min_duration_seconds',
          'available_audio_formats/wav/mime_type',
          'available_audio_formats/wav/extension',
          'available_audio_formats/wav/url',
          'available_audio_formats/wav/start_offset',
          'available_audio_formats/wav/end_offset',
          'available_image_formats',
          'available_image_formats/png',
          'available_image_formats/png/channel',
          'available_image_formats/png/sample_rate',
          'available_image_formats/png/window',
          'available_image_formats/png/colour',
          'available_image_formats/png/ppms',
          'available_image_formats/png/max_duration_seconds',
          'available_image_formats/png/min_duration_seconds',
          'available_image_formats/png/mime_type',
          'available_image_formats/png/extension',
          'available_image_formats/png/url',
          'available_image_formats/png/start_offset',
          'available_image_formats/png/end_offset',
          'available_image_formats/png/window_function',
          'available_text_formats',
          'available_text_formats/json',
          'available_text_formats/json/extension',
          'available_text_formats/json/mime_type',
          'available_text_formats/json/url',
          'available_text_formats/json/start_offset',
          'available_text_formats/json/end_offset'
      ]

      json_paths.each do |expected_json_path|
        response_body.should have_json_path(expected_json_path), "Expected #{expected_json_path} in #{response_body}"
      end

      json_paths_exclude = %w(time date available_image_formats/jpg 'available_image_formats/jpeg)

      json_paths_exclude.each do |unexpected_json_path|
        response_body.should_not have_json_path(unexpected_json_path), "Did not expect #{unexpected_json_path} in #{response_body}"
      end

      parsed = JsonSpec::Helpers::parse_json(response_body)
      remaining = parse_deep(nil, parsed, json_paths.dup, [])
      expect(remaining).to be_empty, "expected no additional elements, got #{remaining}."
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

end
