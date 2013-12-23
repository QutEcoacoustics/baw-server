require 'spec_helper'
require 'modules/audio'
require 'modules/exceptions'

describe MediaTools::AudioMaster do

  let(:audio_file_mono) { File.join(File.dirname(__FILE__), 'test-audio-mono.ogg') }
  let(:audio_file_stereo) { File.join(File.dirname(__FILE__), 'test-audio-stereo.ogg') }
  let(:audio_file_3_channels) { File.join(File.dirname(__FILE__), 'test-audio-3-channels.ogg') }
  let(:audio_file_empty) { File.join(File.dirname(__FILE__), 'test-audio-empty.ogg') }
  let(:audio_file_corrupt) { File.join(File.dirname(__FILE__), 'test-audio-corrupt.ogg') }
  let(:audio_file_does_not_exist_1) { File.join(File.dirname(__FILE__), 'not-here-1.ogg') }
  let(:audio_file_does_not_exist_2) { File.join(File.dirname(__FILE__), 'not-here-2.ogg') }
  let(:temp_dir) { File.join(File.dirname(__FILE__), '..', '..', 'tmp') }
  let(:audio_master) { MediaTools::AudioMaster.new(temp_dir) }
  let(:temp_audio_file_1) { File.join(temp_dir, 'temp-audio-1') }
  let(:temp_audio_file_2) { File.join(temp_dir, 'temp-audio-2') }
  let(:temp_audio_file_3) { File.join(temp_dir, 'temp-audio-3') }

  after(:each) do
    Dir.glob(temp_audio_file_1+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_2+'*.*').each { |f| File.delete(f) }
    Dir.glob(temp_audio_file_3+'*.*').each { |f| File.delete(f) }
  end

  context 'when getting audio file information' do
    it 'runs to completion when given an existing file' do
      audio_master.info(audio_file_stereo)
    end

    it 'causes exception for invalid path' do
      expect {
        audio_master.info(audio_file_does_not_exist_1)
      }.to raise_error(Exceptions::FileNotFoundError)
    end

    it 'gets the correct channel count for mono audio file' do
      info = audio_master.info(audio_file_mono)
      expect(info[:channels]).to eql(1)
    end

    it 'gets the correct channel count for stereo audio file' do
      info = audio_master.info(audio_file_stereo)
      expect(info[:channels]).to eql(2)
    end

    it 'gets the correct channel count for 3 channel audio file' do
      info = audio_master.info(audio_file_3_channels)
      expect(info[:channels]).to eql(3)
    end

    it 'gives correct error for empty file' do
      expect {
        audio_master.info(audio_file_empty)
      }.to raise_error(Exceptions::FileEmptyError)

    end

    it 'gives correct error for corrupt file' do
      expect {
        audio_master.info(audio_file_corrupt)
      }.to raise_error(Exceptions::FileCorruptError)
    end
  end

  context 'when modifying audio file' do
    it 'causes exception for invalid path' do
      expect {
        audio_master.modify(audio_file_does_not_exist_1, audio_file_does_not_exist_2, {})
      }.to raise_error(Exceptions::FileNotFoundError)
    end

    it 'causes exception for same path for source and target' do
      expect {
        audio_master.modify(audio_file_stereo, audio_file_stereo, {})
      }.to raise_error(ArgumentError)
    end

    it 'correctly converts entire audio file from .ogg to .wav' do
      temp_audio_file = temp_audio_file_1+'.wav'
      result = audio_master.modify(audio_file_stereo, temp_audio_file, {})
    end

    it 'correctly converts entire audio file from .ogg to .mp3' do
      temp_audio_file = temp_audio_file_1+'.mp3'
      result = audio_master.modify(audio_file_stereo, temp_audio_file, {})


    end

    it 'correctly converts entire audio file from .ogg to .webm' do
      temp_audio_file = temp_audio_file_1+'.webm'
      result = audio_master.modify(audio_file_stereo, temp_audio_file, {})
    end

    it 'correctly converts entire audio file from .ogg to .wav' do
      temp_audio_file = temp_audio_file_1+'.wav'
      result = audio_master.modify(audio_file_stereo, temp_audio_file, {})
    end

    it 'correctly converts entire audio file from .ogg to .wav then entire file to .mp3' do
      temp_audio_file_a = temp_audio_file_1+'.wav'
      result_1 = audio_master.modify(audio_file_stereo, temp_audio_file_a, {})

      temp_audio_file_b = temp_audio_file_2+'.mp3'
      result_2 = audio_master.modify(temp_audio_file_a, temp_audio_file_b, {})
    end

    it 'correctly converts segment of audio file from .ogg to .wv, then to .wav, then to .webm' do
      temp_audio_file_a = temp_audio_file_1+'.wv'
      result_1 = audio_master.modify(audio_file_stereo, temp_audio_file_a, {start_offset: 10, end_offset: 20})

      temp_audio_file_b = temp_audio_file_2+'.wav'
      result_2 = audio_master.modify(temp_audio_file_a, temp_audio_file_b, {})

      temp_audio_file_c = temp_audio_file_3+'.webm'
      result_3 = audio_master.modify(temp_audio_file_b, temp_audio_file_c, {})
    end

  end
end