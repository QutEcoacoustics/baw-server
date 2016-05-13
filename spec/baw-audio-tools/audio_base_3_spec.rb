require 'spec_helper'

# tests getting audio info
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
      }.to raise_error(BawAudioTools::Exceptions::AudioToolError, /string=End of file/)
    end

    it 'returns all required information' do
      info = audio_base.info(audio_file_stereo)
      expect(info).to include(:bit_rate_bps)
      expect(info).to include(:channels)
      expect(info).to include(:data_length_bytes)
      expect(info).to include(:duration_seconds)
      expect(info).to include(:media_type)
      expect(info).to include(:sample_rate)
      expect(info.size).to eq(8)
    end

    it 'ignores low level warnings for ffmpeg' do
      input =
          "[wav @ 0x1d35020] max_analyze_duration 5000000 reached at 5015510 microseconds
[wav @ 0x1d35020] Estimating duration from bitrate, this may be inaccurate
[mp3 @ 0x2935600] overread, skip -6 enddists: -4 -4"
      expect {
        audio_base.audio_ffmpeg.check_for_errors({stderr: input})
      }.to_not raise_error
    end

    it 'fails on unknown warnings for ffmpeg' do
      input =
          "[wav @ 0x1d35020] max_analyze_duration 5000000 reached at 5015510 microseconds
[wav @ 0x1d35020] Estimating duration from bitrate, this may be inaccurate
[mp3 @ 0x2935600] overread, skip -6 enddists: -4 -4
[wav @ 0x1d35020] this one is not known"
      expect {
        audio_base.audio_ffmpeg.check_for_errors({stderr: input})
      }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /Ffmpeg output contained warning/)
    end

  end

  context 'getting info succeeds when' do

    it 'processes a valid .wv file' do
      temp_media_file_a = temp_media_file_1+'.wv'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/wavpack')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .mp3 file' do
      temp_media_file_a = temp_media_file_1+'.mp3'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/mp3')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .asf file' do
      temp_media_file_a = temp_media_file_1+'.asf'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/asf')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .wav file' do
      temp_media_file_a = temp_media_file_1+'.wav'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/wav')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end


    it 'processes a valid .flac file' do
      temp_media_file_a = temp_media_file_1+'.flac'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/x-flac')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .ogg file' do
      temp_media_file_a = temp_media_file_1+'.ogg'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(audio_file_stereo)
      expect(result[:media_type]).to eq('audio/ogg')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .wma file' do
      temp_media_file_a = temp_media_file_1+'.wma'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/asf')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'processes a valid .webm file' do
      temp_media_file_a = temp_media_file_1+'.webm'
      audio_base.modify(audio_file_stereo, temp_media_file_a)
      result = audio_base.info(temp_media_file_a)
      expect(result[:media_type]).to eq('audio/webm')
      expect(result[:sample_rate]).to be_within(1.0).of(44100.0)
      expect(result[:duration_seconds]).to be_within(0.5).of(70.0)
      expect(result[:channels]).to eq(2)
    end

    it 'raises error trying to convert to .wac' do
      expect {
        audio_base.modify(audio_file_stereo, temp_media_file_1 + '.wac')
      }.to raise_error(BawAudioTools::Exceptions::InvalidTargetMediaTypeError)
    end

    it 'processes a valid .wac file' do
      result = audio_base.info(audio_file_wac_2)
      expect(result[:media_type]).to eq('audio/x-waac')
      expect(result[:sample_rate]).to be_within(1.0).of(22050)
      expect(result[:duration_seconds]).to be_within(0.5).of(60.0)
      expect(result[:channels]).to eq(2)
    end
  end
end