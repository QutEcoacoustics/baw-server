# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::Storage::SpectrogramCache do

  let(:spectrogram_cache) { BawWorkers::Config.spectrogram_cache_helper }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:datetime) { Time.zone.parse('2012-03-02 16:05:37+1100') }
  let(:end_offset) { 20.02 }
  let(:partial_path) { uuid[0, 2] }

  let(:start_offset) { 8.1 }
  let(:channel) { 0 }
  let(:sample_rate) { 22_050 }
  let(:format_audio) { 'wav' }
  let(:window) { 1024 }
  let(:window_function) { 'Hann' }
  let(:colour) { 'g' }
  let(:format_spectrogram) { 'jpg' }

  let(:cached_spectrogram_file_name_defaults) { "#{uuid}_0.0_#{end_offset}_0_22050_512_Hamming_g.png" }
  let(:cached_spectrogram_file_name_given_parameters) { "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{sample_rate}_#{window}_#{window_function}_#{colour}.#{format_spectrogram}" }

  let(:opts) {
    {
      uuid: uuid,
      start_offset: start_offset,
      end_offset: end_offset,
      channel: channel,
      sample_rate: sample_rate,
      window: window,
      colour: colour,
      window_function: window_function,
      format: format_spectrogram
    }
  }

  it 'no storage directories exist' do
    expect(spectrogram_cache.existing_dirs).to be_empty
  end

  it 'paths match settings' do
    expect(spectrogram_cache.possible_dirs).to match_array BawWorkers::Settings.paths.cached_spectrograms
  end

  it 'creates the correct name' do
    expect(
      spectrogram_cache.file_name(opts)
    ).to eq cached_spectrogram_file_name_given_parameters
  end

  context 'checking validation of sample rate' do

    let(:non_standard_sample_rate) { 2323 }
    # file name with non-standard sample rate
    let(:cached_spectrogram_file_name_given_parameters_nssr) { "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{non_standard_sample_rate}_#{window}_#{window_function}_#{colour}.#{format_spectrogram}" }

    it 'creates the correct name with non standard original sample rate' do

      expect(
        spectrogram_cache.file_name(
          uuid: uuid,
          start_offset: start_offset,
          end_offset: end_offset,
          channel: channel,
          sample_rate: non_standard_sample_rate,
          original_sample_rate: non_standard_sample_rate,
          window: window,
          colour: colour,
          window_function: window_function,
          format: format_spectrogram
        )
      ).to eq cached_spectrogram_file_name_given_parameters_nssr

    end

    it 'creates the correct name with non standard original sample rate and a standard requested sample rate' do

      expect(
        spectrogram_cache.file_name(
          uuid: uuid,
          start_offset: start_offset,
          end_offset: end_offset,
          channel: channel,
          sample_rate: sample_rate,
          original_sample_rate: non_standard_sample_rate,
          window: window,
          colour: colour,
          window_function: window_function,
          format: format_spectrogram
        )
      ).to eq cached_spectrogram_file_name_given_parameters

    end

    it 'fails validation with non-standard sample rate different from specified original sample rate' do

      expect {
        spectrogram_cache.file_name(
          uuid: uuid,
          start_offset: start_offset,
          end_offset: end_offset,
          channel: channel,
          sample_rate: 75_757,
          original_sample_rate: 12_345,
          window: window,
          colour: colour,
          window_function: window_function,
          format: format_spectrogram
        )
      }.to raise_error(ArgumentError)

    end

    it 'fails validation with non standard sample rate and original sample rate not supplied' do

      expect {
        spectrogram_cache.file_name(
          uuid: uuid,
          start_offset: start_offset,
          end_offset: end_offset,
          channel: channel,
          sample_rate: 87,
          window: window,
          colour: colour,
          window_function: window_function,
          format: format_spectrogram
        )
      }.to raise_error(ArgumentError)

    end

  end

  it 'creates the correct partial path' do
    expect(spectrogram_cache.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct full path for a single file' do
    expected = [File.join(BawWorkers::Settings.paths.cached_spectrograms[0], partial_path, cached_spectrogram_file_name_defaults)]
    expect(spectrogram_cache.possible_paths_file(opts, cached_spectrogram_file_name_defaults)).to eq expected
  end

  it 'creates the correct full path' do
    expected = [File.join(BawWorkers::Settings.paths.cached_spectrograms[0], partial_path, cached_spectrogram_file_name_given_parameters)]
    expect(spectrogram_cache.possible_paths(opts)).to eq expected
  end

  it 'parses a valid cache file name correctly' do
    path = spectrogram_cache.possible_paths_file(opts, cached_spectrogram_file_name_given_parameters)

    path_info = spectrogram_cache.parse_file_path(path[0])

    expect(path.size).to eq 1
    expect(path.first).to eq(BawWorkers::Config.spectrogram_cache_helper.possible_dirs[0] + '/54/5498633d-89a7-4b65-8f4a-96aa0c09c619_8.1_20.02_0_22050_1024_Hann_g.jpg')

    expect(path_info.keys.size).to eq 9
    expect(path_info[:uuid]).to eq uuid
    expect(path_info[:start_offset]).to eq start_offset
    expect(path_info[:end_offset]).to eq end_offset
    expect(path_info[:sample_rate]).to eq sample_rate
    expect(path_info[:channel]).to eq channel
    expect(path_info[:window]).to eq window
    expect(path_info[:window_function]).to eq window_function
    expect(path_info[:colour]).to eq colour
    expect(path_info[:format]).to eq format_spectrogram
  end

end
