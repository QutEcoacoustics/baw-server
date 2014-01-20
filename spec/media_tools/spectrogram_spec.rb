require 'spec_helper'
require 'modules/audio'
require 'modules/spectrogram'
require 'modules/exceptions'

describe Spectrogram do

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_file_amp_2_channels) { File.join(File.dirname(__FILE__), 'amp-channels-2.ogg') }
  let(:audio_file_amp_3_channels) { File.join(File.dirname(__FILE__), 'amp-channels-3.ogg') }

  let(:temp_dir) { File.join(Rails.root, 'tmp') }
  let(:audio_master) { AudioMaster.from_executables(
      Settings.audio_tools.ffmpeg_executable, Settings.audio_tools.ffprobe_executable,
      Settings.audio_tools.mp3splt_executable, Settings.audio_tools.sox_executable, Settings.audio_tools.wavpack_executable,
      Settings.cached_audio_defaults,
      temp_dir) }
  let(:spectrogram) { Spectrogram.from_executables(
      audio_master,
      Settings.audio_tools.imagemagick_convert_executable, Settings.audio_tools.imagemagick_identify_executable,
      Settings.cached_spectrogram_defaults, temp_dir) }
  let(:temp_image_file_1) { File.join(temp_dir, 'temp-image-1') }
  let(:temp_image_file_2) { File.join(temp_dir, 'temp-image-2') }

  let(:temp_audio_file_1) { File.join(temp_dir, 'temp-audio-1') }
  let(:temp_audio_file_2) { File.join(temp_dir, 'temp-audio-2') }

  after(:each) do
    Dir.glob(temp_image_file_1+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_image_file_2+'*.*').each { |f| File.delete(f) }

    Dir.glob(temp_audio_file_1+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_2+'*.*').each { |f| File.delete(f) }
  end

  context 'getting info about image' do
    it 'returns all required information' do
      target = temp_image_file_1+'.png'
      spectrogram.modify(audio_file_mono, target)
      info = spectrogram.info(target)
      expect(info).to include(:media_type)
      expect(info).to include(:width)
      expect(info).to include(:height)
      expect(info).to include(:data_length_bytes)
      expect(info.size).to eq(4)
    end
  end

  context 'generating spectrogram' do
    it 'runs to completion when given an existing audio file' do
      target = temp_image_file_1+'.png'
      spectrogram.modify(audio_file_mono, target)
    end

    it 'gives the expected image width' do
      target = temp_image_file_1+'.png'
      spectrogram.modify(audio_file_mono, target, {start_offset: 10, end_offset: 55})
    end

  end
end
