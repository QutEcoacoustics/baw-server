# frozen_string_literal: true



describe BawAudioTools::AudioWac2wav do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:wac2wav) {
    audio_tools = Settings.audio_tools

    BawAudioTools::AudioWac2wav.new(
      audio_tools.wac2wav_executable,
      temp_dir
    )
  }

  context 'wac2wav' do
    it 'creates correct command line' do
      source = audio_file_wac_1
      target = temp_file(extension: '.wav')

      cmd = wac2wav.modify_command(source, target)
      expected = "wac2wavcmd < \"#{source}\" > \"#{target}\""

      expect(cmd).to eq(expected)
    end

    context 'detects and reads the wac header' do
      it 'succeeds for first test wac file' do
        source = audio_file_wac_1
        info = wac2wav.info(source)
        expect(info).to eq(version: 1, channels: 2, frame_size: 128, block_size: 32, media_type: 'audio/x-waac',
                           flags: { wac: 0, triggered: 0, gps: 0, tag: 0 },
                           sample_rate: 22_050, sample_count: 145_024, seek_size: 16, bit_rate_bps: 16,
                           seek_entries: 8192, data_length_bytes: 394_644, duration_seconds: 6.577)
      end
      it 'succeeds for second test wac file' do
        source = audio_file_wac_2
        info = wac2wav.info(source)
        expect(info).to eq(version: 2, channels: 2, frame_size: 128, block_size: 32, media_type: 'audio/x-waac',
                           flags: { wac: 8, triggered: 0, gps: 0, tag: 0 },
                           sample_rate: 22_050, sample_count: 1_328_768, seek_size: 16, bit_rate_bps: 16,
                           seek_entries: 8192, data_length_bytes: 974_218, duration_seconds: 60.262)
      end
    end

    it 'converts from wac to wav' do
      source = audio_file_wac_1
      target = temp_file(extension: '.wav')
      result = audio_base.modify(source, target)
      info = audio_base.info(target)
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info[:channels]).to eq(2)
      expect(info[:duration_seconds]).to be_within(duration_range).of(6.577)
    end

    it 'converts from wac to flac' do
      source = audio_file_wac_1
      target = temp_file(extension: '.flac')
      result = audio_base.modify(source, target)
      info = audio_base.info(target)
      expect(info[:media_type]).to eq('audio/x-flac')
      expect(info[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info[:channels]).to eq(2)
      expect(info[:duration_seconds]).to be_within(duration_range).of(6.577)
    end

    it 'converts from wac to flac' do
      source = audio_file_wac_1
      target = temp_file(extension: '.mp3')
      result = audio_base.modify(source, target)
      info = audio_base.info(target)
      expect(info[:media_type]).to eq('audio/mp3')
      expect(info[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info[:channels]).to eq(2)
      expect(info[:duration_seconds]).to be_within(duration_range).of(6.577)
    end

    it 'allows converting from .wac to .wav, but not back to .wac' do
      temp_media_file_a = temp_file(extension: '.wav')
      result_1 = audio_base.modify(audio_file_wac_2, temp_media_file_a)
      info_1 = audio_base.info(temp_media_file_a)
      expect(info_1[:media_type]).to eq('audio/wav')
      expect(info_1[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info_1[:channels]).to eq(2)
      expect(info_1[:duration_seconds]).to be_within(0.3).of(60)

      temp_media_file_b = temp_file(extension: '.wac')
      expect {
        audio_base.modify(temp_media_file_a, temp_media_file_b)
      }.to raise_error(BawAudioTools::Exceptions::InvalidTargetMediaTypeError, 'Cannot convert to .wac')
    end
  end
end
