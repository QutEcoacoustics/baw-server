shared_context 'common' do
# mp3, webm, ogg (wav, wv)
  let(:duration_range) { 0.11 }
  let(:amplitude_range) { 0.02 }
  let(:bit_rate_range) { 400 }
  let(:bit_rate_min) { 192000 }
  let(:sleep_range) { 0.5 }

  let(:temp_dir) { File.join(File.dirname(__FILE__), '..', '..', 'tmp') }
  let(:audio_dir) { File.join(File.dirname(__FILE__), '..', 'media_files') }

end

shared_context 'audio base' do
  let(:audio_base) { BawAudioTools::AudioBase.from_executables(
      Settings.audio_tools.ffmpeg_executable, Settings.audio_tools.ffprobe_executable,
      Settings.audio_tools.mp3splt_executable, Settings.audio_tools.sox_executable, Settings.audio_tools.wavpack_executable,
      Settings.cached_audio_defaults, temp_dir) }
end

shared_context 'test audio files' do
  let(:audio_file_mono) { File.join(audio_dir, 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_file_stereo) { File.join(audio_dir, 'test-audio-stereo.ogg') }
  let(:audio_file_stereo_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_stereo_sample_rate) { 44100 }
  let(:audio_file_stereo_channels) { 2 }
  let(:audio_file_stereo_duration_seconds) { 70 }

  let(:audio_file_empty) { File.join(audio_dir, 'test-audio-empty.ogg') }
  let(:audio_file_corrupt) { File.join(audio_dir, 'test-audio-corrupt.ogg') }
  let(:audio_file_does_not_exist_1) { File.join(audio_dir, 'not-here-1.ogg') }
  let(:audio_file_does_not_exist_2) { File.join(audio_dir, 'not-here-2.ogg') }
  let(:audio_file_amp_1_channels) { File.join(audio_dir, 'amp-channels-1.ogg') }
  let(:audio_file_amp_2_channels) { File.join(audio_dir, 'amp-channels-2.ogg') }
  let(:audio_file_amp_3_channels) { File.join(audio_dir, 'amp-channels-3.ogg') }
end

shared_context 'temp media files' do
  let(:temp_media_file_1) { File.join(temp_dir, 'temp-media-1') }
  let(:temp_media_file_2) { File.join(temp_dir, 'temp-media-2') }
  let(:temp_media_file_3) { File.join(temp_dir, 'temp-media-3') }
  let(:temp_media_file_4) { File.join(temp_dir, 'temp-media-4') }

  after(:each) do
    Dir.glob(temp_media_file_1+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_media_file_2+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_media_file_3+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_media_file_4+'*.*').each { |f| File.delete(f) }
  end

end