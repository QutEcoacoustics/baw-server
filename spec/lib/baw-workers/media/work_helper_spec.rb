require 'spec_helper'

describe BawWorkers::Media::WorkHelper do
  include_context 'shared_test_helpers'

  let(:work_helper) {
    BawWorkers::Media::WorkHelper.new(
        BawWorkers::Config.audio_helper,
        BawWorkers::Config.spectrogram_helper,
        BawWorkers::Config.original_audio_helper,
        BawWorkers::Config.audio_cache_helper,
        BawWorkers::Config.spectrogram_cache_helper,
        BawWorkers::Config.file_info,
        BawWorkers::Config.logger_worker,
        custom_temp
    )
  }

  let(:audio_dir) { File.join(File.dirname(__FILE__), '..', '..', '..', 'example_media') }

  let(:original_audio_file) { File.join(audio_dir, 'test-audio-mono.ogg') }
  let(:media_type) { Mime::Type.lookup('audio/ogg') }
  let(:sample_rate) { 44100 }
  let(:channels) { 1 }
  let(:duration_seconds) { 70.0 }
  let(:datetime) { Time.zone.parse('2012-03-02 16:05:37Z') }
  let(:original_format) { 'ogg' }
  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }

  let(:original_file_name_old) { "#{uuid}_120303-0205.#{original_format}" } # depends on let(:datetime)
  let(:original_file_name_new) { "#{uuid}_20120302-160537Z.#{original_format}" } # depends on let(:datetime)
  let(:original_file_dir) { File.expand_path File.join(BawWorkers::Settings.paths.original_audios, '54') }
  let(:original_file_path_old) { File.join(original_file_dir, original_file_name_old) }
  let(:original_file_path_new) { File.join(original_file_dir, original_file_name_new) }

  before(:each) do
    FileUtils.mkpath(original_file_dir)
    # src, dest, preserve, dereference
    # If preserve is true, this method preserves owner, group, permissions and modified time.
    FileUtils.copy_file(original_audio_file, original_file_path_old, true)
    FileUtils.copy_file(original_audio_file, original_file_path_new, true)
  end

  after(:each) do
    FileUtils.rm_rf(BawWorkers::Settings.paths.original_audios)
    FileUtils.rm_rf(BawWorkers::Settings.paths.cached_audios)
    FileUtils.rm_rf(BawWorkers::Settings.paths.cached_spectrograms)
    FileUtils.rm_rf(BawWorkers::Settings.paths.cached_datasets)
  end

  it 'raises exception when original audio not found' do
    expect {
      work_helper.create_audio_segment(
          {uuid: '5498633d-89a7-4b65-8f4a-46aa0c09c619',
           datetime_with_offset: datetime,
           original_format: original_format,
           start_offset: 0,
           end_offset: duration_seconds,
           channel: 0,
           sample_rate: sample_rate,
           format: BawWorkers::Settings.cached_audio_defaults.extension
          })
    }.to raise_error(BawAudioTools::Exceptions::AudioFileNotFoundError, /Could not find original audio in/)
  end

  context 'creates cached audio' do
    it 'has correct path and output with custom settings' do
      existing_paths = work_helper.create_audio_segment(
          {
              uuid: uuid,
              datetime_with_offset: datetime,
              original_format: original_format,
              end_offset: 60,
              start_offset: 45,
              channel: 1,
              sample_rate: 22050,
              format: 'wav'
          })
      file_name = "#{uuid}_45.0_60.0_1_22050.wav"
      expect(existing_paths).to include(File.join(BawWorkers::Settings.paths.cached_audios, '54', file_name))
      expect(existing_paths.size).to eq(1)

      info = work_helper.audio.info(existing_paths.first)
      expect(info[:media_type]).to eq('audio/wav')
      expect(info[:sample_rate]).to be_within(0.0).of(22050)
      expect(info[:channels]).to eq(1)
      expect(info[:duration_seconds]).to be_within(duration_range).of(15.0)
    end

    it 'has correct path and output with default settings' do
      existing_paths = work_helper.create_audio_segment(
          {
              uuid: uuid,
              datetime_with_offset: datetime,
              original_format: original_format,
              start_offset: 0,
              end_offset: BawWorkers::Settings.cached_audio_defaults.min_duration_seconds,
              channel: BawWorkers::Settings.cached_audio_defaults.channel,
              sample_rate: BawWorkers::Settings.cached_audio_defaults.sample_rate,
              format: BawWorkers::Settings.cached_audio_defaults.extension
          })
      file_name = "#{uuid}_0.0_#{BawWorkers::Settings.cached_audio_defaults.min_duration_seconds}_"+
          "#{BawWorkers::Settings.cached_audio_defaults.channel}_#{BawWorkers::Settings.cached_audio_defaults.sample_rate}.#{BawWorkers::Settings.cached_audio_defaults.extension}"
      expect(existing_paths).to include(File.join(BawWorkers::Settings.paths.cached_audios, '54', file_name))
      expect(existing_paths.size).to eq(1)

      info = work_helper.audio.info(existing_paths.first)
      expect(info[:media_type]).to eq("audio/#{BawWorkers::Settings.cached_audio_defaults.extension}")
      expect(info[:sample_rate]).to be_within(0.0).of(BawWorkers::Settings.cached_audio_defaults.sample_rate)
      expect(info[:channels]).to eq(1) # number of channels
      expect(info[:duration_seconds]).to be_within(duration_range).of(BawWorkers::Settings.cached_audio_defaults.min_duration_seconds)
    end
  end

  context 'creates cached spectrogram' do

    it 'has correct path and output with custom settings' do
      existing_paths = work_helper.generate_spectrogram(
          {
              uuid: uuid,
              datetime_with_offset: datetime,
              original_format: original_format,
              end_offset: 60,
              start_offset: 45,
              channel: 1,
              sample_rate: 32000,
              window: 1024,
              window_function: 'Hann',
              colour: 'g',
              format: 'png'
          })
      file_name = "#{uuid}_45.0_60.0_1_32000_1024_Hann_g.png"
      expect(existing_paths).to include(File.join(BawWorkers::Settings.paths.cached_spectrograms, '54', file_name))
      expect(existing_paths.size).to eq(1)

      info = work_helper.spectrogram.info(existing_paths.first)
      expect(info[:media_type]).to eq('image/png')
      expect(info[:height]).to eq(1024 / 2)
      expect(info[:width]).to be_within(1).of((32000.0 / 1024.0) * 15.0)
    end

    it 'has correct path and output with default settings' do
      existing_paths = work_helper.generate_spectrogram(
          {
              uuid: uuid,
              datetime_with_offset: datetime,
              original_format: original_format,
              start_offset: 0,
              end_offset: BawWorkers::Settings.cached_spectrogram_defaults.min_duration_seconds,
              channel: BawWorkers::Settings.cached_spectrogram_defaults.channel,
              window: BawWorkers::Settings.cached_spectrogram_defaults.window,
              window_function: BawWorkers::Settings.cached_spectrogram_defaults.window_function,
              colour: BawWorkers::Settings.cached_spectrogram_defaults.colour,
              sample_rate: BawWorkers::Settings.cached_spectrogram_defaults.sample_rate,
              format: BawWorkers::Settings.cached_spectrogram_defaults.extension
          })
      file_name = "#{uuid}_0.0_#{BawWorkers::Settings.cached_spectrogram_defaults.min_duration_seconds}_"+
          "#{BawWorkers::Settings.cached_spectrogram_defaults.channel}_#{BawWorkers::Settings.cached_spectrogram_defaults.sample_rate}_"+
          "#{BawWorkers::Settings.cached_spectrogram_defaults.window}_#{BawWorkers::Settings.cached_spectrogram_defaults.window_function}_"+
          "#{BawWorkers::Settings.cached_spectrogram_defaults.colour}.#{BawWorkers::Settings.cached_spectrogram_defaults.extension}"
      expect(existing_paths).to include(File.join(BawWorkers::Settings.paths.cached_spectrograms, '54', file_name))
      expect(existing_paths.size).to eq(1)

      info = work_helper.spectrogram.info(existing_paths.first)
      expect(info[:media_type]).to eq("image/#{BawWorkers::Settings.cached_spectrogram_defaults.extension}")
      expect(info[:height]).to eq(BawWorkers::Settings.cached_spectrogram_defaults.window / 2)

      pixels_per_second =
          BawWorkers::Settings.cached_spectrogram_defaults.sample_rate.to_f /
              BawWorkers::Settings.cached_spectrogram_defaults.window

      duration = BawWorkers::Settings.cached_spectrogram_defaults.min_duration_seconds

      expect(info[:width]).to be_within(1).of(pixels_per_second * duration)
    end
  end
end