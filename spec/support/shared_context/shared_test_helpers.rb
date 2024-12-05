# frozen_string_literal: true

shared_context 'shared_test_helpers' do
  let(:host) { Settings.host.name }
  let(:port) { Settings.host.port }
  let(:scheme) { BawApp.http_scheme }
  let(:default_uri) { "#{scheme}://#{host}:#{port}" }

  let(:audio_file_mono) { Fixtures.audio_file_mono }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_format) { 'ogg' }
  let(:audio_file_mono_sample_rate) { 44_100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }
  let(:audio_file_mono_data_length_bytes) { 822_281 }
  let(:audio_file_mono_bit_rate_bps) { 239_920 }

  let(:audio_file_mono_29) { Fixtures.audio_file_mono }
  let(:audio_file_mono_29_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_29_format) { 'ogg' }
  let(:audio_file_mono_29_sample_rate) { 44_100 }
  let(:audio_file_mono_29_channels) { 1 }
  let(:audio_file_mono_29_duration_seconds) { 29.0 }
  let(:audio_file_mono_29_data_length_bytes) { 296_756 }
  let(:audio_file_mono_29_bit_rate_bps) { 239_920 }

  let(:audio_file_bar_lt_metadata) {
    return {
      media_type: Mime::Type.lookup('audio/flac'),
      format: 'flac',
      sample_rate: 22_050,
      channels: 1,
      duration_seconds: 7194.749388,
      data_length_bytes: 181_671_228,
      bit_rate_bps: 202_004
    }
  }

  let(:audio_file_wac) { Fixtures.audio_file_wac_1 }

  let(:duration_range) { 0.11 }

  let(:audio_file_corrupt) { Fixtures.audio_file_corrupt }

  let(:temporary_dir) { Settings.paths.temp_dir }

  # output file paths
  let(:harvest_to_do_path) { File.expand_path(Settings.actions.harvest.to_do_path) }
  let(:harvester_to_do_path) { Pathname(File.expand_path(Settings.actions.harvest.to_do_path)) }
  let(:custom_temp) { BawWorkers::Config.temp_dir }

  # easy access to config & settings
  let(:audio) { BawWorkers::Config.audio_helper }
  let(:spectrogram) { BawWorkers::Config.spectrogram_helper }

  let(:audio_original) { BawWorkers::Config.original_audio_helper }
  let(:audio_cache) { BawWorkers::Config.audio_cache_helper }
  let(:spectrogram_cache) { BawWorkers::Config.spectrogram_cache_helper }
  let(:analysis_cache) { BawWorkers::Config.analysis_cache_helper }

  let(:file_info) { BawWorkers::Config.file_info }
  let(:api) { BawWorkers::Config.api_communicator }

  def get_api_security_response(user_name, auth_token)
    {
      meta: {
        status: 200,
        message: 'OK'
      },
      data: {
        auth_token:,
        user_name:,
        message: 'Signed in successfully.'
      }
    }
  end

  def get_api_security_request(email, password)
    {
      email:,
      password:
    }
  end
end
