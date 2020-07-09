# frozen_string_literal: true

require 'workers_helper'
require_relative '../../../helpers/baw_audio_tools_shared'

# tests modifying audio and argument restrictions
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

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
      temp_audio_file = temp_media_file_1 + '.mp3'
      result = audio_base.modify(audio_file_stereo, temp_audio_file, sample_rate: 22_050)
      info = audio_base.info(temp_audio_file)
      expect(File.size(temp_audio_file)).to be > 0
      expect(info[:media_type]).to eq('audio/mp3')
      expect(info[:sample_rate]).to be_within(0.0).of(22_050)
      expect(info[:channels]).to eq(audio_file_stereo_channels)
      expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
      expect(info[:bit_rate_bps]).to be_within(400).of(128_000)
    end
  end
  context 'restrictions are enforced' do
    it 'mp3splt must have a mp3 file as the source' do
      temp_audio_file = temp_media_file_1 + '.mp3'
      expect {
        audio_base.audio_mp3splt.modify_command(audio_file_stereo.to_s, audio_base.info(audio_file_stereo.to_s), temp_audio_file)
      }.to raise_error(ArgumentError, /Source is not a mp3 file/)
    end

    it 'mp3splt must have a mp3 file as the destination' do
      temp_media_file_a = temp_media_file_1 + '.mp3'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/mp3')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
      #expect(info_1[:bit_rate_bps]).to be_within(bit_rate_range).of(bit_rate_min)

      temp_media_file_b = temp_media_file_2 + '.wav'

      expect {
        audio_base.audio_mp3splt.modify_command(temp_media_file_a, audio_base.info(temp_media_file_a), temp_media_file_b)
      }.to raise_error(ArgumentError, /not a mp3 file/)
    end

    it 'wavpack must have a wavpack file as the source' do
      temp_audio_file = temp_media_file_1 + '.mp3'
      expect {
        audio_base.audio_wavpack.modify_command(audio_file_stereo.to_s, audio_base.info(audio_file_stereo.to_s), temp_audio_file)
      }.to raise_error(ArgumentError, /Source is not a wavpack file/)
    end

    it 'wavpack must have a wav file as the destination' do
      temp_media_file_a = temp_media_file_1 + '.wv'
      result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
      info_1 = audio_base.info(temp_media_file_a)
      expect(File.size(temp_media_file_a)).to be > 0
      expect(info_1[:media_type]).to eq('audio/wavpack')
      expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
      expect(info_1[:channels]).to eq(audio_file_stereo_channels)
      expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

      temp_media_file_b = temp_media_file_2 + '.wv'

      expect {
        audio_base.audio_wavpack.modify_command(temp_media_file_a, audio_base.info(temp_media_file_a), temp_media_file_b)
      }.to raise_error(ArgumentError, /not a wav file/)
    end

    it 'wac2wav must have a wac file as the source' do
      temp_audio_file = temp_media_file_1 + '.mp3'
      expect {
        audio_base.audio_wac2wav.modify_command(audio_file_stereo, temp_audio_file)
      }.to raise_error(ArgumentError, /Source is not a wac file/)
    end

    it 'wac2wav must have a wav file as the target' do
      temp_audio_file = temp_media_file_1 + '.mp3'
      expect {
        audio_base.audio_wac2wav.modify_command(audio_file_wac_1, temp_audio_file)
      }.to raise_error(ArgumentError, /Target is not a wav file/)
    end
  end
end
