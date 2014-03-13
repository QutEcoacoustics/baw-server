require 'fileutils'
require 'active_support/all'
require 'spec_helper'
require File.dirname(__FILE__) + '/shared_spec_helper'
require File.dirname(__FILE__) + '/../../lib/baw-audio-tools/string'
require File.dirname(__FILE__) + '/../../lib/baw-audio-tools/media_cacher'

describe BawAudioTools::MediaCacher do
  include_context 'common'

  let(:media_cacher) { BawAudioTools::MediaCacher.new(temp_dir) }

  let(:original_audio_file) { File.join(audio_dir, 'test-audio-stereo.ogg') }
  let(:media_type) { Mime::Type.lookup('audio/ogg') }
  let(:sample_rate) { 44100 }
  let(:channels) { 2 }
  let(:duration_seconds) { 70.0 }
  let(:datetime) { Time.zone.parse("2012-03-02 16:05:37") }
  let(:original_format) { 'ogg' }
  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }

  let(:original_file_name) { "#{uuid}_#{datetime.strftime('%y%m%d')}-#{datetime.strftime('%H%M')}.#{original_format}" }
  let(:original_file_dir) { File.join(Settings.paths.original_audios, '54') }
  let(:original_file_path) { File.join(original_file_dir, original_file_name) }

  before(:each) do
    FileUtils.mkpath(original_file_dir)
    # src, dest, preserve, dereference
    # If preserve is true, this method preserves owner, group, permissions and modified time.
    FileUtils.copy_file(original_audio_file, original_file_path, true)
  end

  after(:each) do
    FileUtils.rm_rf(Settings.paths.original_audios)
    FileUtils.rm_rf(Settings.paths.cached_audios)
    FileUtils.rm_rf(Settings.paths.cached_spectrograms)
    FileUtils.rm_rf(Settings.paths.cached_datasets)
  end

  it 'raises exception when original audio not found' do
    expect {
      media_cacher.create_audio_segment(
          {uuid: '5498633d-89a7-4b65-8f4a-46aa0c09c619',
           date: datetime,
           time: datetime,
           original_format: original_format,
           start_offset: 0,
           end_offset: duration_seconds,
           channel: 0,
           sample_rate: sample_rate,
           format: Settings.cached_audio_defaults.storage_format
          })
    }.to raise_error(BawAudioTools::Exceptions::AudioFileNotFoundError, /Could not find original audio in/)
  end

  context 'creates cached audio' do
    it 'has correct path and output with custom settings' do
      existing_paths = media_cacher.create_audio_segment(
          {
              uuid: uuid,
              date: datetime,
              time: datetime,
              original_format: original_format,
              end_offset: 60,
              start_offset: 45,
              channel: 1,
              sample_rate: 17640,
              format: 'wav'
          })
      file_name = "#{uuid}_45.0_60.0_1_17640.wav"
      expect(existing_paths).to include(File.join(Settings.paths.cached_audios, '54', file_name))
      existing_paths.should have(1).items

      info = media_cacher.audio.info(existing_paths.first)
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(17640)
      expect(info[:channels]).to eq(1)
      expect(info[:duration_seconds]).to be_within(duration_range).of(15.0)
    end

    it 'has correct path and output with default settings' do
      existing_paths = media_cacher.create_audio_segment(
          {
              uuid: uuid,
              date: datetime,
              time: datetime,
              original_format: original_format,
              start_offset: 0,
              end_offset: Settings.cached_audio_defaults.min_duration_seconds,
              channel: Settings.cached_audio_defaults.channel,
              sample_rate: Settings.cached_audio_defaults.sample_rate,
              format: Settings.cached_audio_defaults.storage_format
          })
      file_name = "#{uuid}_0.0_#{Settings.cached_audio_defaults.min_duration_seconds}_"+
          "#{Settings.cached_audio_defaults.channel}_#{Settings.cached_audio_defaults.sample_rate}.#{Settings.cached_audio_defaults.storage_format}"
      expect(existing_paths).to include(File.join(Settings.paths.cached_audios, '54', file_name))
      existing_paths.should have(1).items

      info = media_cacher.audio.info(existing_paths.first)
      expect(info[:media_type]).to eq("audio/#{Settings.cached_audio_defaults.storage_format}")
      expect(info[:sample_rate]).to be_within(0.0).of(Settings.cached_audio_defaults.sample_rate)
      expect(info[:channels]).to eq(1) # number of channels
      expect(info[:duration_seconds]).to be_within(duration_range).of(Settings.cached_audio_defaults.min_duration_seconds)
    end
  end

  context 'creates cached spectrogram' do

    it 'has correct path and output with custom settings' do
      existing_paths = media_cacher.generate_spectrogram(
          {
              uuid: uuid,
              date: datetime,
              time: datetime,
              original_format: original_format,
              end_offset: 60,
              start_offset: 45,
              channel: 1,
              sample_rate: 17640,
              window: 1024,
              colour: 'g',
              format: 'png'
          })
      file_name = "#{uuid}_45.0_60.0_1_17640_1024_g.png"
      expect(existing_paths).to include(File.join(Settings.paths.cached_spectrograms, '54',file_name ))
      existing_paths.should have(1).items

      info = media_cacher.spectrogram.info(existing_paths.first)
      expect(info[:media_type]).to eq('image/png')
      expect(info[:height]).to eq(1024 / 2)
      expect(info[:width]).to be_within(1).of(0.043 * (15.0 * 1000))
    end

    it 'has correct path and output with default settings' do
      existing_paths = media_cacher.generate_spectrogram(
          {
              uuid: uuid,
              date: datetime,
              time: datetime,
              original_format: original_format,
              start_offset: 0,
              end_offset: Settings.cached_spectrogram_defaults.min_duration_seconds,
              channel: Settings.cached_spectrogram_defaults.channel,
              window: Settings.cached_spectrogram_defaults.window,
              colour: Settings.cached_spectrogram_defaults.colour,
              sample_rate: Settings.cached_spectrogram_defaults.sample_rate,
              format: Settings.cached_spectrogram_defaults.storage_format
          })
      file_name =  "#{uuid}_0.0_#{Settings.cached_spectrogram_defaults.min_duration_seconds}_"+
          "#{Settings.cached_spectrogram_defaults.channel}_#{Settings.cached_spectrogram_defaults.sample_rate}_"+
          "#{Settings.cached_spectrogram_defaults.window}_#{Settings.cached_spectrogram_defaults.colour}.#{Settings.cached_spectrogram_defaults.storage_format}"
      expect(existing_paths).to include(File.join(Settings.paths.cached_spectrograms, '54', file_name))
      existing_paths.should have(1).items

      info = media_cacher.spectrogram.info(existing_paths.first)
      expect(info[:media_type]).to eq("image/#{Settings.cached_spectrogram_defaults.storage_format}")
      expect(info[:height]).to eq(Settings.cached_spectrogram_defaults.window / 2)
      expect(info[:width]).to be_within(1).of(0.043 * (Settings.cached_spectrogram_defaults.min_duration_seconds * 1000))
    end
  end
end