# frozen_string_literal: true

require 'workers_helper'

describe BawAudioTools::Spectrogram do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:spectrogram) {
    audio_tools = Settings.audio_tools

    BawAudioTools::Spectrogram.from_executables(
      audio_base,
      audio_tools.imagemagick_convert_executable,
      audio_tools.imagemagick_identify_executable,
      Settings.cached_spectrogram_defaults,
      temp_dir
    )
  }

  context 'getting info about image' do
    it 'returns all required information' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      spectrogram.modify(source, target)
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
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      spectrogram.modify(source, target)
    end
  end

  context 'generating waveform' do
    it 'runs to completion when given an existing audio file' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      expect {
        spectrogram.modify(source, target, colour: 'w', sample_rate: 22_050)
      }.to raise_error(NotImplementedError, 'Drawing waveforms has been deprecated and is no longer supported')
    end
  end
end
