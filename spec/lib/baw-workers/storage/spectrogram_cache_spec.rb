require 'spec_helper'

describe BawWorkers::Storage::SpectrogramCache do

  let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms) }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:datetime) { Time.zone.parse("2012-03-02 16:05:37+1100") }
  let(:end_offset) { 20.02 }
  let(:partial_path) { uuid[0, 2] }

  let(:start_offset) { 8.1 }
  let(:channel) { 0 }
  let(:sample_rate) { 22050 }
  let(:format_audio) { 'wav' }
  let(:window) { 1024 }
  let(:window_function) { "Hann" }
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

end