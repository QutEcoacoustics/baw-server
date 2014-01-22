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
    temp_audio_file = temp_audio_file_1+'.wav'
    audio_base.modify(audio_file_amp_2_channels, temp_audio_file,
                      {
                          start_offset: 3,
                          end_offset: 9,
                          channel: 1,
                          sample_rate: 17640
                      }
    )
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(17640)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(6)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.2)
  end

  it 'segments and converts successfully for 1 channel' do
    temp_audio_file = temp_audio_file_1+'.wav'
    audio_base.modify(audio_file_amp_1_channels, temp_audio_file,
                      {
                          start_offset: 2.5,
                          end_offset: 7.5,
                          channel: 1,
                          sample_rate: 17640
                      }
    )
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/wav')
    expect(info[:sample_rate]).to be_within(0.0).of(17640)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(5)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.5)
  end

  it 'mixes 2 channels down to mono' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, {channel: 0})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.43) # 0.2, 0.4 = 0.43
  end

  it 'mixes 3 channels down to mono' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, {channel: 0})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.81) # 0.1, 0.3, 0.6 = 0.81
  end

  it 'selects the first of two channels' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, {channel: 1})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.2)
  end

  it 'selects the second of two channels' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_2_channels, temp_audio_file, {channel: 2})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.4)
  end

  it 'selects the first of three channels' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, {channel: 1})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.1)
  end

  it 'selects the second of three channels' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, {channel: 2})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.6) # this is the third channel as created by audacity
  end

  it 'selects the third of three channels' do
    temp_audio_file = temp_audio_file_1+'.ogg'
    result = audio_base.modify(audio_file_amp_3_channels, temp_audio_file, {channel: 3})
    info = audio_base.info(temp_audio_file)
    expect(info[:media_type]).to eq('audio/ogg')
    expect(info[:sample_rate]).to be_within(0.0).of(44100)
    expect(info[:channels]).to eq(1)
    expect(info[:duration_seconds]).to be_within(duration_range).of(10)
    expect(info[:max_amplitude]).to be_within(amplitude_range).of(0.3) # this is the second channel as created by audacity
  end
end