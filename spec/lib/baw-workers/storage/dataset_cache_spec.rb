require 'spec_helper'

describe BawWorkers::Storage::DatasetCache do

  let(:dataset_cache) { BawWorkers::Config.dataset_cache_helper }

  let(:saved_search_id) { 1 }
  let(:dataset_id) { 1 }
  let(:dataset_format) { 'txt' }
  let(:opts) {
    {
        saved_search_id: saved_search_id,
        dataset_id: dataset_id,
        format: dataset_format
    }
  }

  let(:cached_dataset_file_name) { "#{saved_search_id}_#{dataset_id}.#{dataset_format}" }

  it 'no storage directories exist' do
    expect(dataset_cache.existing_dirs).to be_empty
  end

  it 'paths match settings' do
    expect(dataset_cache.possible_dirs).to match_array BawWorkers::Settings.paths.cached_datasets
  end

  it 'creates the correct name' do
    #
    expect(
        dataset_cache.file_name(opts)
    ).to eq cached_dataset_file_name
  end

  it 'creates the correct full path' do
    expected = [File.join(BawWorkers::Settings.paths.cached_datasets[0], cached_dataset_file_name)]
    expect(dataset_cache.possible_paths(opts)).to eq expected
  end
end