# frozen_string_literal: true

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

  context 'when getting info about image' do
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

  context 'when generating a spectrogram' do
    before do
      FileUtils.mkdir_p(temp_dir / 'demo')
    end

    it 'runs to completion when given an existing audio file' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      spectrogram.modify(source, target)

      # copy file for manual inspection
      FileUtils.copy_file(target, temp_dir / 'demo' / target.basename)
    end

    [:h, :high_contrast,
     :pr, :pink_red,
     :tg, :teal_green,
     :yg, :yellow_green,
     :gr, :green_red,
     :tb, :teal_blue,
     :rb, :red_blue].each do |option|
      it "can generate colour spectrograms (#{option})" do
        source = temp_file(extension: '.wav')
        audio_base.modify(audio_file_mono, source)

        target = temp_file(stem: option, extension: '.png')
        spectrogram.modify(source, target, colour: option)
        # copy file for manual inspection
        FileUtils.copy_file(target, temp_dir / 'demo' / target.basename)
      end
    end

    it 'will reject other colours' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      expect {
        spectrogram.modify(source, target, colour: 'idontexist')
      }.to raise_error(ArgumentError, /Colour must be one of/)
    end
  end

  context 'when generating a waveform' do
    it 'runs to completion when given an existing audio file' do
      source = temp_file(extension: '.wav')
      audio_base.modify(audio_file_mono, source)

      target = temp_file(extension: '.png')
      spectrogram.modify(source, target, colour: 'w', sample_rate: 22_050)
    end
  end
end
