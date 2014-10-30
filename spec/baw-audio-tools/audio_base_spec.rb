require 'spec_helper'

describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  context 'when getting audio file information' do
    it 'runs to completion when given an existing file' do
      audio_base.info(audio_file_stereo)
    end

    it 'causes exception for invalid path' do
      expect {
        audio_base.info(audio_file_does_not_exist_1)
      }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError)
    end

    it 'gives correct error for empty file' do
      expect {
        audio_base.info(audio_file_empty)
      }.to raise_error(BawAudioTools::Exceptions::FileEmptyError)
    end

    it 'gives correct error for corrupt file' do
      expect {
        audio_base.info(audio_file_corrupt)
      }.to raise_error(BawAudioTools::Exceptions::FileCorruptError)
    end

    it 'returns all required information' do
      info = audio_base.info(audio_file_stereo)
      expect(info).to include(:media_type)
      expect(info).to include(:sample_rate)
      expect(info).to include(:bit_rate_bps)
      expect(info).to include(:bit_rate_bps_calc)
      expect(info).to include(:data_length_bytes)
      expect(info).to include(:channels)
      expect(info).to include(:duration_seconds)
      expect(info).to include(:max_amplitude)
      expect(info.size).to eq(8)
    end
  end

  context 'when modifying audio file' do
    it 'causes exception for invalid path' do
      expect {
        audio_base.modify(audio_file_does_not_exist_1, audio_file_does_not_exist_2)
      }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError)
    end

    it 'causes exception for same path for source and target' do
      expect {
        audio_base.modify(audio_file_stereo, audio_file_stereo)
      }.to raise_error(ArgumentError, /Source and Target are the same file/)
    end

    it 'successfully converts sample rate' do
      temp_audio_file = temp_media_file_1+'.mp3'
      result = audio_base.modify(audio_file_stereo, temp_audio_file, {sample_rate: 22050})
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/mp3')
      expect(info[:sample_rate]).to be_within(0.0).of(22050)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
      expect(info[:bit_rate_bps]).to be >= 128000
    end

  end
  context 'restrictions are enforced' do
    it 'mp3splt must have a mp3 file as the source' do
      temp_audio_file = temp_media_file_1+'.mp3'
      expect {
        audio_base.audio_mp3splt.modify_command(audio_file_stereo, audio_base.info(audio_file_stereo), temp_audio_file)
      }.to raise_error(ArgumentError, /Source is not a mp3 file/)
    end

    it 'mp3splt must have a mp3 file as the destination' do
      temp_media_file_a = temp_media_file_1+'.mp3'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/mp3')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
      #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

      temp_media_file_b = temp_media_file_2+'.wav'

      expect {
        audio_base.audio_mp3splt.modify_command(temp_media_file_a, audio_base.info(temp_media_file_a), temp_media_file_b)
      }.to raise_error(ArgumentError, /not a mp3 file/)
    end

    it 'wavpack must have a wavpack file as the source' do
      temp_audio_file = temp_media_file_1+'.mp3'
      expect {
        audio_base.audio_wavpack.modify_command(audio_file_stereo, audio_base.info(audio_file_stereo), temp_audio_file)
      }.to raise_error(ArgumentError, /Source is not a wavpack file/)
    end

    it 'wavpack must have a wav file as the destination' do
      temp_media_file_a = temp_media_file_1+'.wv'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/wavpack')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

      temp_media_file_b = temp_media_file_2+'.wv'

      expect {
        audio_base.audio_wavpack.modify_command(temp_media_file_a, audio_base.info(temp_media_file_a), temp_media_file_b)
      }.to raise_error(ArgumentError, /not a wav file/)
    end
  end


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
 
  context 'verifying integrity' do
    context 'succeeds' do
      it 'processing valid .wv file' do
        temp_media_file_a = temp_media_file_1+'.wv'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:operation]).to eq('verified')
        expect(result[:info][:mode]).to eq('lossless')
      end

      it 'processing valid .mp3 file' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .asf file' do
        temp_media_file_a = temp_media_file_1+'.asf'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .wav file' do
        temp_media_file_a = temp_media_file_1+'.wav'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end


      it 'processing valid .flac file' do
        temp_media_file_a = temp_media_file_1+'.flac'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .ogg file' do
        temp_media_file_a = temp_media_file_1+'.ogg'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .wma file' do
        temp_media_file_a = temp_media_file_1+'.wma'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .webm file' do
        temp_media_file_a = temp_media_file_1+'.webm'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end

      it 'processing valid .webm file' do
        temp_media_file_a = temp_media_file_1+'.webm'
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        result = audio_base.integrity_check(temp_media_file_a)
        expect(result[:errors].size).to eq(0)
        expect(result[:info][:read][:samples]).to eq(result[:info][:write][:samples])
      end
    end
    context 'fails' do
      it 'processing empty .ogg file' do
        result = audio_base.integrity_check(audio_file_empty)

        expect(result[:errors].size).to eq(2)

        expect(result[:errors][0][:id]).to eq('ogg')
        expect(result[:errors][0][:description]).to eq('Format ogg detected only with low score of 1, misdetection possible!')

        expect(result[:errors][1][:id]).to eq('end of file')
        expect(result[:errors][1][:description]).to include('End of file')

      end

      it 'processing empty .mp3 file' do
        temp_media_file_a = temp_media_file_1+'.mp3'
        FileUtils.touch(temp_media_file_a)

        result = audio_base.integrity_check(temp_media_file_a)

        expect(result[:errors].size).to eq(2)

        expect(result[:errors][0][:id]).to eq('mp3')
        expect(result[:errors][0][:description]).to eq('Format mp3 detected only with low score of 1, misdetection possible!')

        expect(result[:errors][1][:id]).to eq('mp3')
        expect(result[:errors][1][:description]).to eq('Could not find codec parameters for stream 0 (Audio: mp3, 0 channels, s16p): unspecified frame size')

      end

      it 'processing corrupt .ogg file' do

        result = audio_base.integrity_check(audio_file_corrupt)

        expect(result[:errors].size).to be > 2

        expect(result[:errors][0][:id]).to eq('NULL')
        expect(result[:errors][0][:description]).to eq('Invalid Setup header')

        expect(result[:errors][1][:id]).to eq('vorbis')
        expect(result[:errors][1][:description]).to eq('Extradata missing.')

        #expect(result[:errors][5][:id]).to eq('error')
        #expect(result[:errors][5][:description]).to include('Error while opening decoder for input stream #0:0 : Invalid data found when processing input')

      end
    end
  end
end


