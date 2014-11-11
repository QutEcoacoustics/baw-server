require 'spec_helper'

describe BawAudioTools::AudioWaveform do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:waveform){
    audio_tools = RSpec.configuration.test_settings.audio_tools

    BawAudioTools::AudioWaveform.new(
        audio_tools.wav2png_executable,
        temp_dir)
  }

  context 'waveform' do
    it 'creates correct command line' do

      source = temp_media_file_1+'.wav'
      audio_base.modify(audio_file_mono, source)

      target = temp_media_file_1+'.png'
      cmd = waveform.command(source, nil, target)

      expect(cmd).to include("wav2png  --background-color efefefff --foreground-color 00000000 --width 1800 --height 280 --db-max 0 --db-min -48 --output \"")
    end

    it 'respects custom options in command line' do
      source = temp_media_file_1+'.wav'
      audio_base.modify(audio_file_mono, source)

      target = temp_media_file_1+'.png'
      cmd = waveform.command(source, nil, target,
                       width = 2000, height = 500,
                       colour_bg = '000000ff', colour_fg = '00000000',
                       scale = :logarithmic,
                       db_min = -60, db_max = 10)

      expect(cmd).to include("wav2png --db-scale --background-color 000000ff --foreground-color 00000000 --width 2000 --height 500 --db-max 10 --db-min -60 --output \"")
    end

  end
end