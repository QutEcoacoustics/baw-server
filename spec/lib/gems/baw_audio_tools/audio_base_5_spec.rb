# frozen_string_literal: true

require 'workers_helper'

# tests converting between audio formats
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  it 'correctly converts from .ogg to .wav' do
    temp_audio_file = temp_media_file_1 + '.wav'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .oga' do
    temp_audio_file = temp_media_file_1 + '.oga'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3' do
    temp_audio_file = temp_media_file_1 + '.mp3'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp3')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .asf' do
    temp_audio_file = temp_media_file_1 + '.asf'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/asf')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp4' do
    temp_audio_file = temp_media_file_1 + '.mp4'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp4')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .flac' do
    temp_audio_file = temp_media_file_1 + '.flac'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/x-flac')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .webm' do
    temp_audio_file = temp_media_file_1 + '.webm'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .webma' do
    temp_audio_file = temp_media_file_1 + '.webma'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wv' do
    temp_audio_file = temp_media_file_1 + '.wv'
    _ = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wavpack')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .mp3' do
    temp_media_file_a = temp_media_file_1 + '.wav'
    _ = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info1 = audio_base.info(temp_media_file_a)
    expect(info1[:media_type]).to eq('audio/wav')
    expect(info1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info1[:channels]).to eq(audio_file_stereo_channels)
    expect(info1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2 + '.mp3'
    _ = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info2 = audio_base.info(temp_media_file_b)
    expect(info2[:media_type]).to eq('audio/mp3')
    expect(info2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info2[:channels]).to eq(audio_file_stereo_channels)
    expect(info2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .ogg' do
    temp_media_file_a = temp_media_file_1 + '.wav'
    _ = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info1 = audio_base.info(temp_media_file_a)
    expect(info1[:media_type]).to eq('audio/wav')
    expect(info1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info1[:channels]).to eq(audio_file_stereo_channels)
    expect(info1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2 + '.ogg'
    _ = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info2 = audio_base.info(temp_media_file_b)
    expect(info2[:media_type]).to eq('audio/ogg')
    expect(info2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info2[:channels]).to eq(audio_file_stereo_channels)
    expect(info2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3, then from .mp3 to .wav' do
    temp_media_file_a = temp_media_file_1 + '.mp3'
    _ = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info1 = audio_base.info(temp_media_file_a)
    expect(info1[:media_type]).to eq('audio/mp3')
    expect(info1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info1[:channels]).to eq(audio_file_stereo_channels)
    expect(info1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2 + '.wav'
    _ = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info2 = audio_base.info(temp_media_file_b)
    expect(info2[:media_type]).to eq('audio/wav')
    expect(info2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info2[:channels]).to eq(audio_file_stereo_channels)
    expect(info2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .wac to .wav, then from .wav to .flac' do
    temp_media_file_a = temp_media_file_1 + '.wav'
    _ = audio_base.modify(audio_file_wac_2, temp_media_file_a)
    info1 = audio_base.info(temp_media_file_a)
    expect(info1[:media_type]).to eq('audio/wav')
    expect(info1[:sample_rate]).to be_within(0.0).of(22_050)
    expect(info1[:channels]).to eq(2)
    expect(info1[:duration_seconds]).to be_within(0.3).of(60)

    temp_media_file_b = temp_media_file_2 + '.flac'
    _ = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info2 = audio_base.info(temp_media_file_b)
    expect(info2[:media_type]).to eq('audio/x-flac')
    expect(info2[:sample_rate]).to be_within(0.0).of(22_050)
    expect(info2[:channels]).to eq(2)
    expect(info2[:duration_seconds]).to be_within(0.3).of(60)
  end
end
