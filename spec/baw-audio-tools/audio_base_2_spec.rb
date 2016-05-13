require 'spec_helper'

# tests segmenting audio files
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  context 'segmenting audio file' do
    it 'gets the correct segment of the file when only start_offset is specified' do
      temp_audio_file = temp_media_file_1+'.wav'
      result = audio_base.modify(audio_file_stereo, temp_audio_file, {start_offset: 10})
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
    end

    it 'gets the correct segment of the file when only end_offset is specified' do
      temp_audio_file = temp_media_file_1+'.wav'
      result = audio_base.modify(audio_file_stereo, temp_audio_file, {end_offset: 20})
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(20)
    end

    it 'correctly converts from .ogg to .wv, then to from .wv to .wav' do
      temp_media_file_a = temp_media_file_1+'.wv'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, {start_offset: 10, end_offset: 20})
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/wavpack')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(10)

      temp_media_file_b = temp_media_file_2+'.wav'
      result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
      info_2 = audio_base.info(temp_media_file_b)
      expect(File.size(temp_media_file_b)).to be > 0
      expect(info_2[:media_type]).to eq('audio/wav')
      expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_2[:channels]).to eq(audio_file_stereo_channels)
      expect(info_2[:duration_seconds]).to be_within(duration_range).of(10)
    end

    it 'correctly converts from .ogg to .webm, then to from .webm to .ogg' do
      temp_media_file_a = temp_media_file_1+'.webm'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, {start_offset: 10, end_offset: 20})
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/webm')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(10)

      temp_media_file_b = temp_media_file_2+'.ogg'
      result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
      info_2 = audio_base.info(temp_media_file_b)
      expect(File.size(temp_media_file_b)).to be > 0
      expect(info_2[:media_type]).to eq('audio/ogg')
      expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_2[:channels]).to eq(audio_file_stereo_channels)
      expect(info_2[:duration_seconds]).to be_within(duration_range).of(10)
      expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
    end

    it 'correctly converts from .ogg to .mp3, then to from .mp3 to .wav' do
      temp_media_file_a = temp_media_file_1+'.mp3'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, {start_offset: 10, end_offset: 40, sample_rate: 22050})
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/mp3')
      expect(info_1[:sample_rate]).to be_within(0.0).of(22050)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(30)
      # ogg doesn't have a set bit rate

      temp_media_file_b = temp_media_file_2+'.wav'
      result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
      info_2 = audio_base.info(temp_media_file_b)
      expect(File.size(temp_media_file_b)).to be > 0
      expect(info_2[:media_type]).to eq('audio/wav')
      expect(info_2[:sample_rate]).to be_within(0.0).of(22050)
      expect(info_2[:channels]).to eq(audio_file_stereo_channels)
      expect(info_2[:duration_seconds]).to be_within(duration_range).of(30)
    end

    it 'correctly converts from .ogg to .flac' do
      temp_media_file_a = temp_media_file_1+'.flac'
      result = audio_base.modify(audio_file_stereo, temp_media_file_a, {start_offset: 10, end_offset: 40, sample_rate: 22050})
      info = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info[:media_type]).to eq('audio/x-flac')
      expect(info[:sample_rate]).to be_within(0.0).of(22050)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(30)
    end

    context 'special case for wavpack files' do
      it 'gets the correct segment of the file when only start_offset is specified' do
        temp_media_file_a = temp_media_file_1+'.wv'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_media_file_2+'.wav'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {start_offset: 10})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/wav')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
      end

      it 'gets the correct segment of the file when only end_offset is specified' do
        temp_media_file_a = temp_media_file_1+'.wv'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_media_file_2+'.wav'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {end_offset: 20})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/wav')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(20)
      end

      it 'gets the correct segment of the file when only offsets are specified' do
        temp_media_file_a = temp_media_file_1+'.wv'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_media_file_2+'.wav'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {start_offset: 10, end_offset: 20})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/wav')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(10)
      end
    end

    context 'special case for mp3 files' do
      it 'gets the correct segment of the file when only start_offset is specified' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/mp3')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
        #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

        temp_media_file_b = temp_media_file_2+'.mp3'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {start_offset: 10})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/mp3')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
        #expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
      end

      it 'gets the correct segment of the file when only end_offset is specified' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/mp3')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
        #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

        temp_media_file_b = temp_media_file_2+'.mp3'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {end_offset: 20})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/mp3')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(20)
        #expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
      end

      it 'gets the correct segment of the file when only offsets are specified' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/mp3')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
        # converting from ogg has problems: ogg doesn't allow bit rates to be specified
        #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
        #expect(info_1[:bit_rate_bps_calc]).to be_within(bit_rate_range).of(bit_rate_min)

        temp_media_file_b = temp_media_file_2+'.mp3'
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, {start_offset: 10, end_offset: 20})
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/mp3')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(10)
        #expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
        #expect(info_2[:bit_rate_bps_calc]).to be_within(bit_rate_range).of(bit_rate_min)
      end
    end
  end
end