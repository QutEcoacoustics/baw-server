require 'spec_helper'

# tests converting between audio formats
describe BawAudioTools::AudioBase do
  include_context 'common'
  include_context 'audio base'
  include_context 'temp media files'
  include_context 'test audio files'

  it 'correctly converts from .ogg to .wav' do
    temp_audio_file = temp_media_file_1+'.wav'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .oga' do
    temp_audio_file = temp_media_file_1+'.oga'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3' do
    temp_audio_file = temp_media_file_1+'.mp3'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp3')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .asf' do
    temp_audio_file = temp_media_file_1+'.asf'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/asf')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp4' do
    temp_audio_file = temp_media_file_1+'.mp4'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp4')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .flac' do
    temp_audio_file = temp_media_file_1+'.flac'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/x-flac')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .webm' do
    temp_audio_file = temp_media_file_1+'.webm'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .webma' do
    temp_audio_file = temp_media_file_1+'.webma'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wv' do
    temp_audio_file = temp_media_file_1+'.wv'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wavpack')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .mp3' do
    temp_media_file_a = temp_media_file_1+'.wav'
    result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info_1 = audio_base.info(temp_media_file_a)
    expect(info_1[:media_type]).to eq('audio/wav')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2+'.mp3'
    result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info_2 = audio_base.info(temp_media_file_b)
    expect(info_2[:media_type]).to eq('audio/mp3')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .ogg' do
    temp_media_file_a = temp_media_file_1+'.wav'
    result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info_1 = audio_base.info(temp_media_file_a)
    expect(info_1[:media_type]).to eq('audio/wav')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2+'.ogg'
    result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info_2 = audio_base.info(temp_media_file_b)
    expect(info_2[:media_type]).to eq('audio/ogg')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3, then from .mp3 to .wav' do
    temp_media_file_a = temp_media_file_1+'.mp3'
    result_1 = audio_base.modify(audio_file_stereo, temp_media_file_a)
    info_1 = audio_base.info(temp_media_file_a)
    expect(info_1[:media_type]).to eq('audio/mp3')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_media_file_b = temp_media_file_2+'.wav'
    result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info_2 = audio_base.info(temp_media_file_b)
    expect(info_2[:media_type]).to eq('audio/wav')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .wac to .wav, then from .wav to .flac' do
    temp_media_file_a = temp_media_file_1+'.wav'
    result_1 = audio_base.modify(audio_file_wac_2, temp_media_file_a)
    info_1 = audio_base.info(temp_media_file_a)
    expect(info_1[:media_type]).to eq('audio/wav')
    expect(info_1[:sample_rate]).to be_within(0.0).of(22050)
    expect(info_1[:channels]).to eq(2)
    expect(info_1[:duration_seconds]).to be_within(0.3).of(60)

    temp_media_file_b = temp_media_file_2+'.flac'
    result_2 = audio_base.modify(temp_media_file_a, temp_media_file_b)
    info_2 = audio_base.info(temp_media_file_b)
    expect(info_2[:media_type]).to eq('audio/x-flac')
    expect(info_2[:sample_rate]).to be_within(0.0).of(22050)
    expect(info_2[:channels]).to eq(2)
    expect(info_2[:duration_seconds]).to be_within(0.3).of(60)
  end
end