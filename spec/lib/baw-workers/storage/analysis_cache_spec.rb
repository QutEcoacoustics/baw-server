require 'spec_helper'

describe BawWorkers::Storage::AnalysisCache do

  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs) }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }

  let(:analysis_id) { 'analysis_id_valid.-486NDHF' }
  let(:analysis_id_invalid) { 'analysis_id_invalid-04a bKE_-.5:+@ *LQ<' }
  let(:analysis_id_invalid_normalised) { 'analysis_id_invalid-04a_bKE_-.5_____LQ_' }

  let(:result_file_name) { 'file_name_valid.4567menfASD-' }
  let(:result_file_name_invalid) { 'result_file_name_invalid-04a bKE_-.5:+@ *LQ<' }
  let(:result_file_name_invalid_normalised) { 'result_file_name_invalid-04a_bKE_-.5_____LQ_' }

  let(:cached_analysis_file_name_given_parameters) {
    File.join(analysis_id.gsub(normalise_regex, '_').downcase, result_file_name.downcase) }

  let(:normalise_regex) {/[^0-9a-zA-Z_\-\.]/}
  let(:partial_path) {
    first = uuid[0, 2].downcase
    second = uuid.downcase

    File.join(first, second)

  }

  let(:opts) {
    {
        uuid: uuid.downcase,
        analysis_id: analysis_id.downcase,
        result_file_name: result_file_name.downcase
    }
  }


  it 'no storage directories exist' do
    expect(analysis_cache.existing_dirs).to be_empty
  end

  it 'paths match settings' do
    expect(analysis_cache.possible_dirs).to match_array BawWorkers::Settings.paths.cached_analysis_jobs
  end

  it 'creates the correct name' do
    expect(
        analysis_cache.file_name(opts)
    ).to eq cached_analysis_file_name_given_parameters
  end

  it 'creates the correct partial path' do
    expect(analysis_cache.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct full path for a single file' do
    expected = [File.join(BawWorkers::Settings.paths.cached_analysis_jobs[0], partial_path, cached_analysis_file_name_given_parameters)]
    expect(analysis_cache.possible_paths_file(opts, cached_analysis_file_name_given_parameters)).to eq expected
  end

  it 'creates the correct full path' do
    expected = [File.join(BawWorkers::Settings.paths.cached_analysis_jobs[0], partial_path, cached_analysis_file_name_given_parameters)]
    expect(analysis_cache.possible_paths(opts)).to eq expected
  end

  it 'creates the correct full path for a single file with invalid chars' do

    first = uuid[0, 2].downcase
    second = uuid.downcase
    third = analysis_id_invalid_normalised.downcase

    mod_partial_path = File.join(first, second, third)

    mod_opts = {
        uuid: uuid,
        analysis_id: analysis_id_invalid,
        result_file_name: result_file_name_invalid
    }

    expected = [File.join(BawWorkers::Settings.paths.cached_analysis_jobs[0], mod_partial_path, result_file_name_invalid_normalised.downcase)]
    expect(analysis_cache.possible_paths_file(mod_opts, analysis_cache.file_name({result_file_name: result_file_name_invalid, analysis_id: analysis_id_invalid}))).to eq expected
  end

end