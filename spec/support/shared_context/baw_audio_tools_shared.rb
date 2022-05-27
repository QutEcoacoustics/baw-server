# frozen_string_literal: true

shared_context 'common' do
  # mp3, webm, ogg (wav, wv)
  let(:duration_range) { 0.11 }
  let(:amplitude_range) { 0.02 }
  let(:bit_rate_range) { 400 }
  let(:bit_rate_min) { 192_000 }
end

shared_context 'audio base' do
  # let(:temp_dir) { Settings.paths.temp_dir }

  let(:audio_dir) { Fixtures::FILES_PATH }

  # let(:logger) {
  #   logger = Logger.new(BawApp.root / 'log' / 'audio_tools.test.log')
  #   logger.level = Logger::INFO
  #   logger
  # }

  let(:audio_base) {
    audio_tools = Settings.audio_tools

    BawAudioTools::AudioBase.from_executables(
      Settings.cached_audio_defaults,
      logger,
      Settings.paths.temp_dir,
      Settings.audio_tools_timeout_sec,
      ffmpeg: audio_tools.ffmpeg_executable,
      ffprobe: audio_tools.ffprobe_executable,
      mp3splt: audio_tools.mp3splt_executable,
      sox: audio_tools.sox_executable,
      wavpack: audio_tools.wavpack_executable,
      shntool: audio_tools.shntool_executable,
      wac2wav: audio_tools.wac2wav_executable
    )
  }
end

shared_context 'test audio files' do
  let(:audio_file_mono) { Fixtures.audio_file_mono }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44_100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_file_stereo) { Fixtures.audio_file_stereo }
  let(:audio_file_stereo_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_stereo_sample_rate) { 44_100 }
  let(:audio_file_stereo_channels) { 2 }
  let(:audio_file_stereo_duration_seconds) { 70 }

  let(:audio_file_7777hz) { Fixtures.audio_file_stereo_7777hz }
  let(:audio_file_7777hz_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_7777hz_sample_rate) { 7777 }
  let(:audio_file_7777hz_channels) { 2 }
  let(:audio_file_7777hz_duration_seconds) { 70 }

  let(:audio_file_empty) { Fixtures.audio_file_empty }
  let(:audio_file_corrupt) { Fixtures.audio_file_corrupt }
  let(:audio_file_does_not_exist_1) { Fixtures::FILES_PATH / 'not-here-1.ogg' }
  let(:audio_file_does_not_exist_2) { Fixtures::FILES_PATH / 'not-here-2.ogg' }
  let(:audio_file_amp_1_channels) { Fixtures.audio_file_amp_channels_1 }
  let(:audio_file_amp_2_channels) { Fixtures.audio_file_amp_channels_2 }
  let(:audio_file_amp_3_channels) { Fixtures.audio_file_amp_channels_3 }

  let(:audio_file_wac_1) { Fixtures.audio_file_wac_1 }

  let(:audio_file_wac_2) { Fixtures.audio_file_wac_2 }
end

shared_context 'temp media files' do
  let(:temp_media_file_1) { temp_file(stem: 'temp-media-1', extension: '') }
  let(:temp_media_file_2) { temp_file(stem: 'temp-media-2', extension: '') }
  let(:temp_media_file_3) { temp_file(stem: 'temp-media-3', extension: '') }
  let(:temp_media_file_4) { temp_file(stem: 'temp-media-4', extension: '') }
end
