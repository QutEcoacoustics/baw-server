require 'spec_helper'
require 'modules/audio_base'
require 'modules/exceptions'

describe AudioBase do

  # mp3, webm, ogg (wav, wv)
  let(:duration_range) { 0.15 }
  let(:amplitude_range) { 0.019 }

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), 'test-audio-mono.ogg') }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_sample_rate) { 44100 }
  let(:audio_file_mono_channels) { 1 }
  let(:audio_file_mono_duration_seconds) { 70 }

  let(:audio_file_stereo) { File.join(File.dirname(__FILE__), 'test-audio-stereo.ogg') }
  let(:audio_file_stereo_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_stereo_sample_rate) { 44100 }
  let(:audio_file_stereo_channels) { 2 }
  let(:audio_file_stereo_duration_seconds) { 70 }

  let(:audio_file_empty) { File.join(File.dirname(__FILE__), 'test-audio-empty.ogg') }
  let(:audio_file_corrupt) { File.join(File.dirname(__FILE__), 'test-audio-corrupt.ogg') }
  let(:audio_file_does_not_exist_1) { File.join(File.dirname(__FILE__), 'not-here-1.ogg') }
  let(:audio_file_does_not_exist_2) { File.join(File.dirname(__FILE__), 'not-here-2.ogg') }
  let(:audio_file_amp_1_channels) { File.join(File.dirname(__FILE__), 'amp-channels-1.ogg') }
  let(:audio_file_amp_2_channels) { File.join(File.dirname(__FILE__), 'amp-channels-2.ogg') }
  let(:audio_file_amp_3_channels) { File.join(File.dirname(__FILE__), 'amp-channels-3.ogg') }

  let(:temp_dir) { File.join(Rails.root, 'tmp') }
  let(:audio_base) { AudioBase.from_executables(
      Settings.audio_tools.ffmpeg_executable, Settings.audio_tools.ffprobe_executable,
      Settings.audio_tools.mp3splt_executable, Settings.audio_tools.sox_executable, Settings.audio_tools.wavpack_executable,
      Settings.cached_audio_defaults, temp_dir) }
  let(:temp_audio_file_1) { File.join(temp_dir, 'temp-audio-1') }
  let(:temp_audio_file_2) { File.join(temp_dir, 'temp-audio-2') }
  let(:temp_audio_file_3) { File.join(temp_dir, 'temp-audio-3') }
  let(:temp_audio_file_4) { File.join(temp_dir, 'temp-audio-4') }

  #let(:temp_audio_file_1) { File.join(temp_dir, "#{described_class} #{example.description}#{SecureRandom.hex(3)}".gsub(/[^A-Za-z 0-9]+/, '')) }
  #let(:temp_audio_file_2) { File.join(temp_dir, "#{described_class} #{example.description}#{SecureRandom.hex(3)}".gsub(/[^A-Za-z 0-9]+/, '')) }
  #let(:temp_audio_file_3) { File.join(temp_dir, "#{described_class} #{example.description}#{SecureRandom.hex(3)}".gsub(/[^A-Za-z 0-9]+/, '')) }
  #let(:temp_audio_file_4) { File.join(temp_dir, "#{described_class} #{example.description}#{SecureRandom.hex(3)}".gsub(/[^A-Za-z 0-9]+/, '')) }

  after(:each) do
    Dir.glob(temp_audio_file_1+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_2+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_3+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_4+'*.*').each { |f| File.delete(f) }
  end

  it 'correctly converts from .ogg to .wav' do
    temp_audio_file = temp_audio_file_1+'.wav'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .oga' do
    temp_audio_file = temp_audio_file_1+'.oga'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3' do
    temp_audio_file = temp_audio_file_1+'.mp3'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp3')

    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .asf' do
    temp_audio_file = temp_audio_file_1+'.asf'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/asf')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp4' do
    temp_audio_file = temp_audio_file_1+'.mp4'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/mp4')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .flac' do
    temp_audio_file = temp_audio_file_1+'.flac'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/x-flac')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .webm' do
    temp_audio_file = temp_audio_file_1+'.webm'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end


  it 'correctly converts from .ogg to .webma' do
    temp_audio_file = temp_audio_file_1+'.webma'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/webm')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wv' do
    temp_audio_file = temp_audio_file_1+'.wv'
    result = audio_base.modify(audio_file_stereo, temp_audio_file)
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wavpack')
    expect(info[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info[:channels]).to eq(audio_file_stereo_channels)
    expect(info[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .mp3' do
    temp_audio_file_a = temp_audio_file_1+'.wav'
    result_1 = audio_base.modify(audio_file_stereo, temp_audio_file_a)
    info_1 = audio_base.info(temp_audio_file_a)
    expect(info_1[:media_type]).to eq('audio/wav')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_audio_file_b = temp_audio_file_2+'.mp3'
    result_2 = audio_base.modify(temp_audio_file_a, temp_audio_file_b)
    info_2 = audio_base.info(temp_audio_file_b)
    expect(info_2[:media_type]).to eq('audio/mp3')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .wav, then from .wav to .ogg' do
    temp_audio_file_a = temp_audio_file_1+'.wav'
    result_1 = audio_base.modify(audio_file_stereo, temp_audio_file_a)
    info_1 = audio_base.info(temp_audio_file_a)
    expect(info_1[:media_type]).to eq('audio/wav')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_audio_file_b = temp_audio_file_2+'.ogg'
    result_2 = audio_base.modify(temp_audio_file_a, temp_audio_file_b)
    info_2 = audio_base.info(temp_audio_file_b)
    expect(info_2[:media_type]).to eq('audio/ogg')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end

  it 'correctly converts from .ogg to .mp3, then from .mp3 to .wav' do
    temp_audio_file_a = temp_audio_file_1+'.mp3'
    result_1 = audio_base.modify(audio_file_stereo, temp_audio_file_a)
    info_1 = audio_base.info(temp_audio_file_a)
    expect(info_1[:media_type]).to eq('audio/mp3')
    expect(info_1[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_1[:channels]).to eq(audio_file_stereo_channels)
    expect(info_1[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)

    temp_audio_file_b = temp_audio_file_2+'.wav'
    result_2 = audio_base.modify(temp_audio_file_a, temp_audio_file_b)
    info_2 = audio_base.info(temp_audio_file_b)
    expect(info_2[:media_type]).to eq('audio/wav')
    expect(info_2[:sample_rate]).to be_within(0.0).of(audio_file_stereo_sample_rate)
    expect(info_2[:channels]).to eq(audio_file_stereo_channels)
    expect(info_2[:duration_seconds]).to be_within(duration_range).of(audio_file_stereo_duration_seconds)
  end
end