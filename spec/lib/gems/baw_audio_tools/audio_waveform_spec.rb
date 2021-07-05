# frozen_string_literal: true

describe BawAudioTools::AudioWaveform do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:waveform) {
    audio_tools = Settings.audio_tools

    BawAudioTools::AudioWaveform.new(
      audio_tools.ffmpeg_executable,
      temp_dir
    )
  }

  context 'when generating waveform commands' do
    it 'creates correct command line' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      cmd = waveform.command(source, nil, target)

      expect(cmd).to include(
        "ffmpeg -nostdin -i '#{source}' -filter_complex 'showwavespic=scale=lin:colors=#FF932900:size=1800x280' '#{target}'"
      )
    end

    it 'respects custom options in command line' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      cmd = waveform.command(source, nil, target,
                             width: 2000, height: 500, colour_fg: '00000000',
                             scale: :log)

      expect(cmd).to include(
        "ffmpeg -nostdin -i '#{source}' -filter_complex 'showwavespic=scale=log:colors=#00000000:size=2000x500' '#{target}'"
      )
    end
  end
end
