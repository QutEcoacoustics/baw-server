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

  it 'parses a valid cache file name correctly' do
    path = dataset_cache.possible_paths_file(opts, cached_dataset_file_name)

    path_info = dataset_cache.parse_file_path(path[0])

    expect(path.size).to eq 1
    expect(path.first).to eq "./tmp/custom_temp_dir/_cached_dataset/1_1.txt"

    expect(path_info.keys.size).to eq 3
    expect(path_info[:saved_search_id]).to eq saved_search_id
    expect(path_info[:dataset_id]).to eq dataset_id
    expect(path_info[:format]).to eq dataset_format
  end

end