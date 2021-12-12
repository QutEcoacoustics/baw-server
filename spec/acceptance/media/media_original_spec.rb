# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'
require 'helpers/resque_helpers'
require 'fixtures/fixtures'

# https://github.com/zipmark/rspec_api_documentation
resource 'Media/original' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  after do
    remove_media_dirs
  end

  # prepare ids needed for paths in requests below
  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:audio_recording_id) { audio_recording.id }

  let(:audio_file_mono) { Fixtures.audio_file_mono }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_size_bytes) { 822_281 }
  let(:audio_file_mono_sample_rate) { 44_100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_original) {
    BawWorkers::Storage::AudioOriginal.new(Settings.paths.original_audios)
  }
  let(:audio_cache) { BawWorkers::Storage::AudioCache.new(Settings.paths.cached_audios) }
  let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(Settings.paths.cached_spectrograms) }
  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(Settings.paths.cached_analysis_jobs) }

  ################################
  # ORIGINAL
  ################################
  describe 'original audio download' do
    before do
      # the standard media route only allows short recordings, purposely mock a long duration to make sure long
      # original recordings succeed.
      audio_recording.update_attribute(:duration_seconds, 3600) # one hour
      create_media_options(audio_recording, audio_file_mono)
    end

    after do
      remove_media_dirs
    end

    def full_file_result(context, opts)
      filename = context.audio_recording.friendly_name
      opts.merge!({
        expected_response_content_type: context.audio_recording.media_type,
        expected_response_has_content: true,
        expected_response_header_values_match: false,
        expected_response_header_values: {
          'Content-Length' => context.audio_file_mono_size_bytes.to_s,
          'Content-Disposition' => "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}",
          'Digest' => "SHA256=#{context.audio_recording.split_file_hash[1]}"
        },
        is_range_request: false
      })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { reader_token }

      standard_request_options(:get, 'ORIGINAL (as reader)', :forbidden,
        { expected_json_path: get_json_error_path(:permissions) })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { writer_token }

      standard_request_options(:get, 'ORIGINAL (as writer)', :forbidden,
        { expected_json_path: get_json_error_path(:permissions) })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { no_access_token }

      standard_request_options(:get, 'ORIGINAL (as no access)', :forbidden,
        { expected_json_path: get_json_error_path(:permissions) })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { invalid_token }

      standard_request_options(:get, 'ORIGINAL (with invalid token)', :unauthorized,
        { expected_json_path: get_json_error_path(:sign_in) })
    end

    get '/audio_recordings/:audio_recording_id/original' do
      parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

      let(:authentication_token) { owner_token }

      standard_request_options(:get, 'ORIGINAL (as owner token)', :forbidden,
        { expected_json_path: get_json_error_path(:permissions) })
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
        }
      )
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
        }
      )
    end
  end
end
