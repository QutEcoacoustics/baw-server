# frozen_string_literal: true

# tests segmenting audio files
describe BawAudioTools::AudioBase, '#audio_tool_segment' do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  context 'segmenting audio file' do
    it 'gets the correct segment of the file when only start_offset is specified' do
      temp_audio_file = temp_file(extension: '.wav')
      result = audio_base.modify(audio_file_stereo, temp_audio_file, start_offset: 10)
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
    end

    it 'gets the correct segment of the file when only end_offset is specified' do
      temp_audio_file = temp_file(extension: '.wav')
      result = audio_base.modify(audio_file_stereo, temp_audio_file, end_offset: 20)
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(20)
    end

    it 'correctly converts from .ogg to .wv, then to from .wv to .wav' do
      temp_media_file_a = temp_file(extension: '.wv')
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, start_offset: 10, end_offset: 20)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/wavpack')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(10)

      temp_media_file_b = temp_file(extension: '.wav')
      result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
      info_2 = audio_base.info(temp_media_file_b)
      expect(File.size(temp_media_file_b)).to be > 0
      expect(info_2[:media_type]).to eq('audio/wav')
      expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_2[:channels]).to eq(audio_file_stereo_channels)
      expect(info_2[:duration_seconds]).to be_within(duration_range).of(10)
    end

    it 'correctly converts from .ogg to .webm, then to from .webm to .ogg' do
      temp_media_file_a = temp_file(extension: '.webm')
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, start_offset: 10, end_offset: 20)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/webm')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(10)

      temp_media_file_b = temp_file(extension: '.ogg')
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
      temp_media_file_a = temp_file(extension: '.mp3')
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a, start_offset: 10, end_offset: 40,
                                                                         sample_rate: 22_050)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/mp3')
      expect(info_1[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(30)
      # ogg doesn't have a set bit rate

      temp_media_file_b = temp_file(extension: '.wav')
      result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
      info_2 = audio_base.info(temp_media_file_b)
      expect(File.size(temp_media_file_b)).to be > 0
      expect(info_2[:media_type]).to eq('audio/wav')
      expect(info_2[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info_2[:channels]).to eq(audio_file_stereo_channels)
      expect(info_2[:duration_seconds]).to be_within(duration_range).of(30)
    end

    it 'correctly converts from .ogg to .flac' do
      temp_media_file_a = temp_file(extension: '.flac')
      result = audio_base.modify(audio_file_stereo, temp_media_file_a, start_offset: 10, end_offset: 40,
                                                                       sample_rate: 22_050)
      info = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info[:media_type]).to eq('audio/x-flac')
      expect(info[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(30)
    end

    context 'checking validation of sample rate' do
      # sample rate is validated for
      # - making sure that only one of a certain set of 'standard' sample rates are requested, to prevent caching too many versions
      # - making sure that the requested sample rate is supported by the file format (e.g. mp3 can only operate with a given set of sample rates)
      # - therefore, we a sample rate will validate if it's a 'standard' sample rate OR the original audio sample rate, as long as
      #   the format supports it

      it 'fails validation if the requested sample rate is non-standard and not the original sample rate (original_sample_rate is not given)' do
        temp_audio_file = temp_file(extension: '.wav')
        expect {
          audio_base.modify(audio_file_stereo, temp_audio_file, start_offset: 10, end_offset: 40, sample_rate: 6666)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end

      it 'fails validation if the requested sample rate is non-standard and not the original sample rate (original_sample_rate is given)' do
        temp_audio_file = temp_file(extension: '.wav')
        expect {
          audio_base.modify(audio_file_7777hz, temp_audio_file, start_offset: 10, end_offset: 40, sample_rate: 6666,
                                                                original_sample_rate: 7777)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end

      # for sample rate validation, original sample rate can be supplied based on a previous database lookup, or by checking the file
      # depending on the calling methods (and what they need to do anyway). If both are supplied, it checks that they are the same
      it 'errors if the specified original sample rate is not actually the sample rate of the source file (standard original_sample_rate)' do
        temp_audio_file = temp_file(extension: '.wav')
        expect {
          audio_base.modify(audio_file_7777hz, temp_audio_file, start_offset: 10, end_offset: 40, sample_rate: 11_025,
                                                                original_sample_rate: 11_025)
        }.to raise_error(ArgumentError)
      end

      it 'errors if the specified original sample rate is not actually the sample rate of the source file (non-standard original_sample_rate)' do
        temp_audio_file = temp_file(extension: '.wav')
        expect {
          audio_base.modify(audio_file_7777hz, temp_audio_file, start_offset: 10, end_offset: 40, sample_rate: 11_025,
                                                                original_sample_rate: 14_554)
        }.to raise_error(ArgumentError)
      end

      it 'converts from .ogg to .flac with non-standard sample rate if it is the original sample rate' do
        temp_media_file_a = temp_file(extension: '.flac')
        result = audio_base.modify(audio_file_7777hz, temp_media_file_a, start_offset: 10, end_offset: 40,
                                                                         sample_rate: 7777)
        info = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info[:media_type]).to eq('audio/x-flac')
        expect(info[:sample_rate]).to be_within(0.0).of(7777)
      end

      it 'errors if the requested requested sample rate is the original sample rate but is not supported by the target format (mp3)' do
        temp_audio_file = temp_file(extension: '.mp3')
        expect {
          audio_base.modify(audio_file_stereo, temp_audio_file, start_offset: 10, sample_rate: 7777)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end

      it 'correctly converts from .ogg to .webm with non-standard sample rate which it is the original sample rate' do
        temp_media_file_a = temp_file(extension: '.webm')
        result = audio_base.modify(audio_file_7777hz, temp_media_file_a, start_offset: 10, end_offset: 40,
                                                                         sample_rate: 7777)
        info = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info[:media_type]).to eq('audio/webm')
        expect(info[:sample_rate]).to be_within(0.0).of(7777)
      end

      it 'correctly converts from .ogg to .wav with non-standard sample rate which it is the original sample rate' do
        temp_media_file_a = temp_file(extension: '.wav')
        result = audio_base.modify(audio_file_7777hz, temp_media_file_a, start_offset: 10, end_offset: 40,
                                                                         sample_rate: 7777)
        info = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info[:media_type]).to eq('audio/wav')
        expect(info[:sample_rate]).to be_within(0.0).of(7777)
      end

      it 'correctly passes validation for wav when (non-standard) sample rate matches specified original sample rate, and no source info given' do
        expect(
          audio_base.check_sample_rate('target.wav', start_offset: 10, end_offset: 40, sample_rate: 939_393,
                                                     original_sample_rate: 939_393)
        ).to eq(nil)
      end

      it 'correctly passes validation for webm when (non-standard) sample rate matches specified original sample rate, and no source info given' do
        expect(
          audio_base.check_sample_rate('something.webm', start_offset: 10, end_offset: 40, sample_rate: 939_393,
                                                         original_sample_rate: 939_393)
        ).to eq(nil)
      end

      it 'correctly fails validation when (non-standard) sample rate does not match specified original sample rate, and no source info given' do
        expect {
          audio_base.check_sample_rate('target.wav', start_offset: 10, end_offset: 40, sample_rate: 939_393,
                                                     original_sample_rate: 123_456)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end

      it 'correctly fails validation for non-standard sample rate and no original_sample_rate or source info given' do
        expect {
          audio_base.check_sample_rate('target.wav', start_offset: 10, end_offset: 40, sample_rate: 939_393)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end

      it 'correctly fails validation for non-standard sample rate and no original_sample_rate or source info given' do
        expect {
          audio_base.check_sample_rate('target.wav', start_offset: 10, end_offset: 40, sample_rate: 939_393)
        }.to raise_error(BawAudioTools::Exceptions::InvalidSampleRateError)
      end
    end

    context 'special case for wavpack files' do
      it 'gets the correct segment of the file when only start_offset is specified' do
        temp_media_file_a = temp_file(extension: '.wv')
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_file(extension: '.wav')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, start_offset: 10)
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/wav')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
      end

      it 'gets the correct segment of the file when only end_offset is specified' do
        temp_media_file_a = temp_file(extension: '.wv')
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_file(extension: '.wav')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, end_offset: 20)
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/wav')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(20)
      end

      it 'gets the correct segment of the file when only offsets are specified' do
        temp_media_file_a = temp_file(extension: '.wv')
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/wavpack')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

        temp_media_file_b = temp_file(extension: '.wav')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, start_offset: 10, end_offset: 20)
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
        temp_media_file_a = temp_file(extension: '.mp3')
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/mp3')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
        #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

        temp_media_file_b = temp_file(extension: '.mp3')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, start_offset: 10)
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/mp3')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds - 10)
        #expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
      end

      it 'gets the correct segment of the file when only end_offset is specified' do
        temp_media_file_a = temp_file(extension: '.mp3')
        result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
        info_1 = audio_base.info(temp_media_file_a)
        expect(File.size(temp_media_file_a)).to be > 0
        expect(info_1[:media_type]).to eq('audio/mp3')
        expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_1[:channels]).to eq(audio_file_stereo_channels)
        expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
        #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

        temp_media_file_b = temp_file(extension: '.mp3')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, end_offset: 20)
        info_2 = audio_base.info(temp_media_file_b)
        expect(File.size(temp_media_file_b)).to be > 0
        expect(info_2[:media_type]).to eq('audio/mp3')
        expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
        expect(info_2[:channels]).to eq(audio_file_stereo_channels)
        expect(info_2[:duration_seconds]).to be_within(duration_range).of(20)
        #expect(info_2[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)
      end

      it 'gets the correct segment of the file when only offsets are specified' do
        temp_media_file_a = temp_file(extension: '.mp3')
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

        temp_media_file_b = temp_file(extension: '.mp3')
        result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b, start_offset: 10, end_offset: 20)
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
