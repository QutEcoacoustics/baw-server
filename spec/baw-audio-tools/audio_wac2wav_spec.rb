require 'spec_helper'

describe BawAudioTools::AudioWac2wav do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  let(:wac2wav) {
    audio_tools = RSpec.configuration.test_settings.audio_tools

    BawAudioTools::AudioWac2wav.new(
        audio_tools.wac2wav_executable,
        temp_dir)
  }

  context 'wac2wav' do
    it 'creates correct command line' do
      source = audio_file_wac_1
      target = temp_media_file_1+'.wav'

      cmd = wac2wav.modify_command(source, target)
      expected = "wac2wavcmd < \"#{source}\" > \"#{target}\""

      expect(cmd).to eq(expected)
    end

    context 'detects and reads the wac header' do
      it 'succeeds for first test wac file' do
        source = audio_file_wac_1
        info = wac2wav.info(source)
        expect(info).to eq({version: 1, channels: 2, frame_size: 128, block_size: 32, media_type: 'audio/x-waac',
                            flags: {wac: 0, triggered: 0, gps: 0, tag: 0},
                            sample_rate: 22050, sample_count: 145024, seek_size: 16, bit_rate_bps: 16,
                            seek_entries: 8192, data_length_bytes: 394644, duration_seconds: 6.577})
      end
      it 'succeeds for second test wac file' do
        source = audio_file_wac_2
        info = wac2wav.info(source)
        expect(info).to eq({version: 2, channels: 2, frame_size: 128, block_size: 32, media_type: 'audio/x-waac',
                            flags: {wac: 8, triggered: 0, gps: 0, tag: 0},
                            sample_rate: 22050, sample_count: 1328768, seek_size: 16, bit_rate_bps: 16,
                            seek_entries: 8192, data_length_bytes: 974218, duration_seconds: 60.262})
      end
    end

    it 'converts from wac to wav' do
      source = audio_file_wac_1
      target = temp_media_file_1+'.wav'
      result = audio_base.modify(source, target)
      info = audio_base.info(target)
      #expect(info[:media_type]).to eq('audio/ogg')
      #expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      #expect(info[:channels]).to eq(audio_file_stereo_channels)
      #expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
    end

  end
end