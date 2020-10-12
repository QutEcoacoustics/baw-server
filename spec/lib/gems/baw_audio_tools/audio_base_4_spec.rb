# frozen_string_literal: true

require 'workers_helper'
require_relative '../../../helpers/baw_audio_tools_shared'

# tests audio channels
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  it 'gets the correct channel count for mono audio file' do
    info = audio_base.info(audio_file_mono)
    expect(info[:channels]).to eql(1)
  end

  it 'gets the correct channel count for stereo audio file' do
    info = audio_base.info(audio_file_stereo)
    expect(info[:channels]).to eql(2)
  end

  it 'gets the correct channel count for 3 channel audio file' do
    info = audio_base.info(audio_file_amp_3_channels)
    expect(info[:channels]).to eql(3)
  end

  it 'segments and converts successfully for 2 channels' do
    temp_audio_file = temp_file(extension: '.wav')
    audio_base.modify(audio_file_amp_2_channels, temp_audio_file,
                      start_offset: 3,
                      end_offset: 9,
                      channel: 1,
                      sample_rate: 8000)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(8000)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(6)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.2)
  end

  it 'segments and converts successfully for 1 channel' do
    temp_audio_file = temp_file(extension: '.wav')
    audio_base.modify(audio_file_amp_1_channels, temp_audio_file,
                      start_offset: 2.5,
                      end_offset: 7.5,
                      channel: 1,
                      sample_rate: 48_000)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(48_000)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(5)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.5)
  end

  it 'mixes 2 channels down to mono' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, channel: 0)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.43) # 0.2, 0.4 = 0.43
  end

  it 'mixes 3 channels down to mono' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, channel: 0)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.81) # 0.1, 0.3, 0.6 = 0.81
  end

  it 'selects the first of two channels' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, channel: 1)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.2)
  end

  it 'selects the second of two channels' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, channel: 2)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.4)
  end

  it 'selects the first of three channels' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, channel: 1)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.1)
  end

  it 'selects the second of three channels' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, channel: 2)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.6) # this is the third channel as created by audacity
  end

  it 'selects the third of three channels' do
    temp_audio_file = temp_file(extension: '.ogg')
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, channel: 3)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44_100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.3) # this is the second channel as created by audacity
  end
end
