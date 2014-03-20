require 'fileutils'
require 'spec_helper'

describe BawAudioTools::CacheBase do

  let(:cache_base) { BawAudioTools::CacheBase.from_paths(
      Settings.paths.original_audios,
      Settings.paths.cached_audios,
      Settings.paths.cached_spectrograms,
      Settings.paths.cached_datasets) }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:datetime) { Time.zone.parse("2012-03-02 16:05:37+1100") }
  let(:end_offset) { 20.02 }
  let(:partial_path) { uuid[0, 2] }

  let(:start_offset) { 8.1 }
  let(:channel) { 0 }
  let(:sample_rate) { 17640 }
  let(:format_audio) { 'wav' }
  let(:window) { 1024 }
  let(:colour) { 'g' }
  let(:format_spectrogram) { 'jpg' }

  let(:original_format) { 'mp3' }
  let(:original_file_name_old) { "#{uuid}_120302-1505.#{original_format}" } # depends on let(:datetime)
  let(:original_file_name_new) { "#{uuid}_20120302-050537Z.#{original_format}" } # depends on let(:datetime)

  let(:cached_audio_file_name_defaults) { "#{uuid}_0.0_#{end_offset}_0_22050.mp3" }
  let(:cached_audio_file_name_given_parameters) { "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{sample_rate}.#{format_audio}" }

  let(:cached_spectrogram_file_name_defaults) { "#{uuid}_0.0_#{end_offset}_0_22050_512_g.png" }
  let(:cached_spectrogram_file_name_given_parameters) { "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{sample_rate}_#{window}_#{colour}.#{format_spectrogram}" }

  let(:saved_search_id) { 1 }
  let(:dataset_id) { 1 }
  let(:dataset_format) { 'txt' }

  let(:cached_dataset_file_name) { "#{saved_search_id}_#{dataset_id}.#{dataset_format}" }

  context 'original audio' do
    it 'no storage directories exist' do
      expect(cache_base.existing_storage_dirs(cache_base.original_audio)).to be_empty
    end

    it 'possible dirs match settings' do
      cache_base.possible_storage_dirs(cache_base.original_audio).should =~ Settings.paths.original_audios
    end

    it 'existing dirs match settings' do
      Dir.mkdir(Settings.paths.original_audios[0]) unless Dir.exists?(Settings.paths.original_audios[0])
      cache_base.existing_storage_dirs(cache_base.original_audio).should =~ Settings.paths.original_audios
      FileUtils.rm_rf(Settings.paths.original_audios[0])
    end

    it 'possible paths match settings for old names' do
      files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_old)]
      cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_old).should =~ files
    end

    it 'possible paths match settings for new names' do
      files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_new)]
      cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_new).should =~ files
    end

    it 'existing paths match settings for old names' do
      files = [
          File.join(Settings.paths.original_audios[0], partial_path, original_file_name_old)
      ]
      dir = Settings.paths.original_audios[0]
      sub_dir = File.join(dir, partial_path)
      FileUtils.mkpath(sub_dir)
      FileUtils.touch(files[0])
      cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_old).should =~ files
      FileUtils.rm_rf(dir)
    end

    it 'existing paths match settings for new names' do
      files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_new)]
      dir = Settings.paths.original_audios[0]
      sub_dir = File.join(dir, partial_path)
      FileUtils.mkpath(sub_dir)
      FileUtils.touch(files[0])
      cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_new).should =~ files
      FileUtils.rm_rf(dir)
    end

    it 'creates the correct old name' do
      expect(cache_base.original_audio.file_name(uuid, datetime, original_format)).to eq original_file_name_old
    end

    it 'creates the correct new name' do
      expect(cache_base.original_audio.file_name_utc(uuid, datetime, original_format)).to eq original_file_name_new
    end

    it 'creates the correct partial path for old names' do
      expect(cache_base.original_audio.partial_path(original_file_name_old)).to eq partial_path
    end

    it 'creates the correct partial path for new names' do
      expect(cache_base.original_audio.partial_path(original_file_name_new)).to eq partial_path
    end

    it 'creates the correct full path for old names' do
      expected = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_old)]
      expect(cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_old)).to eq expected
    end

    it 'creates the correct full path for new names' do
      expected = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_new)]
      expect(cache_base.possible_storage_paths(cache_base.original_audio, original_file_name_new)).to eq expected
    end

    it 'detects that Date object is not valid' do
      expect{
        cache_base.original_audio.file_name(uuid, datetime.localtime, original_format)
      }.to raise_error(BawAudioTools::Exceptions::CacheRequestError, /Only uses ActiveSupport::TimeWithZone, given/)
    end
  end

  context 'cached audio' do
    it 'no storage directories exist' do
      expect(cache_base.existing_storage_dirs(cache_base.cache_audio)).to be_empty
    end

    it 'paths match settings' do
      cache_base.possible_storage_dirs(cache_base.cache_audio).should =~ Settings.paths.cached_audios
    end

    it 'creates the correct name' do
      # uuid, end_offset, start_offset, channel, sample_rate, format
      expect(
          cache_base.cache_audio.file_name(uuid, start_offset, end_offset, channel, sample_rate, format_audio)
      ).to eq cached_audio_file_name_given_parameters
    end

    it 'creates the correct partial path' do
      expect(cache_base.cache_audio.partial_path(cached_audio_file_name_defaults)).to eq partial_path
    end

    it 'creates the correct full path' do
      expected = [File.join(Settings.paths.cached_audios[0], partial_path, cached_audio_file_name_defaults)]
      expect(cache_base.possible_storage_paths(cache_base.cache_audio, cached_audio_file_name_defaults)).to eq expected
    end
  end


  context 'cached spectrogram' do
    it 'no storage directories exist' do
      expect(cache_base.existing_storage_dirs(cache_base.cache_spectrogram)).to be_empty
    end

    it 'paths match settings' do
      cache_base.possible_storage_dirs(cache_base.cache_spectrogram).should =~ Settings.paths.cached_spectrograms
    end

    it 'creates the correct name' do
      # uuid, end_offset, start_offset, channel, sample_rate, window,colour, format
      expect(
          cache_base.cache_spectrogram.file_name(uuid, start_offset, end_offset, channel, sample_rate, window, colour, format_spectrogram)
      ).to eq cached_spectrogram_file_name_given_parameters
    end

    it 'creates the correct partial path' do
      expect(cache_base.cache_spectrogram.partial_path(cached_spectrogram_file_name_defaults)).to eq partial_path
    end

    it 'creates the correct full path' do
      expected = [File.join(Settings.paths.cached_spectrograms[0], partial_path, cached_spectrogram_file_name_defaults)]
      expect(cache_base.possible_storage_paths(cache_base.cache_spectrogram, cached_spectrogram_file_name_defaults)).to eq expected
    end
  end


  context 'cached dataset' do
    it 'no storage directories exist' do
      expect(cache_base.existing_storage_dirs(cache_base.cache_dataset)).to be_empty
    end

    it 'paths match settings' do
      cache_base.possible_storage_dirs(cache_base.cache_dataset).should =~ Settings.paths.cached_datasets
    end

    it 'creates the correct name' do
      #
      expect(
          cache_base.cache_dataset.file_name(saved_search_id, dataset_id, dataset_format)
      ).to eq cached_dataset_file_name
    end

    it 'creates the correct full path' do
      expected = [File.join(Settings.paths.cached_datasets[0], cached_dataset_file_name)]
      expect(cache_base.possible_storage_paths(cache_base.cache_dataset, cached_dataset_file_name)).to eq expected
    end
  end

end