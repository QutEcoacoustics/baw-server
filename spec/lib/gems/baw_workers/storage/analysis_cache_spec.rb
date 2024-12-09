# frozen_string_literal: true

describe BawWorkers::Storage::AnalysisCache do
  include_context 'shared_test_helpers'

  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(Settings.paths.cached_analysis_jobs) }
  let(:analysis_cache_paths) { Settings.paths.cached_analysis_jobs }
  let(:analysis_cache_path) { Settings.paths.cached_analysis_jobs[0] }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:uuid_chars) { uuid[0, 2] }
  let(:job_id) { 10 }
  let(:job_system) { 'system' }

  let(:sub_folder_valid_1) { 'sub_folder_valid1.-486NDHF' }
  let(:sub_folder_valid_2) { 'sub_folder_valid2.-486NDHF' }

  let(:sub_folder_invalid_1) { 'sub_folder_invalid1-04a bKE_-.5:+@ *LQ<' }
  let(:sub_folder_invalid_1_normalised) { 'sub_folder_invalid1-04a_bKE_-.5_____LQ_' }

  let(:sub_folder_invalid_2) { 'sub_folder_invalid2-04a bKE_-.5:+!?$LQ#' }
  let(:sub_folder_invalid_2_normalised) { 'sub_folder_invalid2-04a_bKE_-.5_____LQ_' }

  let(:file_name_valid) { 'file_name_valid.4567menfASD-' }

  let(:file_name_invalid) { 'result_file_name_invalid-04a bKE_-.5:+@?*LQ<' }
  let(:file_name_invalid_normalised) { 'result_file_name_invalid-04a_bKE_-.5_____LQ_' }

  let(:cached_analysis_file_name_given_parameters) { file_name_valid }

  let(:partial_path) {
    File.join(job_id.to_s,
      uuid_chars,
      uuid,
      sub_folder_valid_1,
      sub_folder_valid_2)
  }

  let(:opts) {
    {
      uuid:,
      sub_folders: [sub_folder_valid_1, sub_folder_valid_2],
      file_name: file_name_valid,
      job_id:
    }
  }

  before do
    clear_analysis_cache
  end

  it 'no storage directories exist' do
    expect_empty_directories(analysis_cache.existing_dirs)
  end

  it 'paths match settings' do
    expect(analysis_cache.possible_dirs).to match_array analysis_cache_paths
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
    expected = [File.join(analysis_cache_path, partial_path, cached_analysis_file_name_given_parameters)]
    expect(analysis_cache.possible_paths_file(opts, cached_analysis_file_name_given_parameters)).to eq expected
  end

  it 'creates the correct full path' do
    expected = [File.join(analysis_cache_path, partial_path, cached_analysis_file_name_given_parameters)]
    expect(analysis_cache.possible_paths(opts)).to eq expected
  end

  it 'creates the correct root path' do
    expected = [File.join(analysis_cache_path, job_id.to_s)]
    expect(analysis_cache.possible_job_paths_dir(opts)).to eq(expected)
  end

  it 'creates the correct full path for a single file with invalid chars using integer job id' do
    expected = [File.join(
      analysis_cache_path,
      File.join(job_id.to_s,
        uuid_chars,
        uuid,
        sub_folder_invalid_1_normalised),
      file_name_invalid_normalised
    )]

    test_opts = {
      uuid:,
      sub_folders: [sub_folder_invalid_1],
      file_name: file_name_invalid,
      job_id:
    }

    test = analysis_cache.possible_paths_file(
      test_opts,
      analysis_cache.file_name(file_name: file_name_invalid)
    )

    expect(test).to eq expected
  end

  it 'prevents valid path with job id ~ from going to other parts of the file system' do
    tilde = '~'

    test_opts = {
      uuid:,
      sub_folders: [tilde],
      file_name: tilde,
      job_id: tilde
    }

    expect {
      analysis_cache.possible_paths_file(
        test_opts,
        analysis_cache.file_name(file_name: tilde)
      )
    }.to raise_error(ArgumentError,
      'job_id must be equal to or greater than 1: ~. Provided parameters: {:uuid=>"5498633d-89a7-4b65-8f4a-96aa0c09c619", :sub_folders=>["~"], :file_name=>"~", :job_id=>"~"}')
  end

  it 'prevents valid path with job id .. from going to other parts of the file system' do
    double_dot = '..'

    test_opts = {
      uuid:,
      sub_folders: [double_dot],
      file_name: double_dot,
      job_id: double_dot
    }

    expect {
      analysis_cache.possible_paths_file(
        test_opts,
        analysis_cache.file_name(file_name: double_dot)
      )
    }.to raise_error(ArgumentError,
      'job_id must be equal to or greater than 1: ... Provided parameters: {:uuid=>"5498633d-89a7-4b65-8f4a-96aa0c09c619", :sub_folders=>[".."], :file_name=>"..", :job_id=>".."}')
  end

  it 'prevents valid path with job id . from going to other parts of the file system' do
    single_dot = '.'

    test_opts = {
      uuid:,
      sub_folders: [single_dot],
      file_name: single_dot,
      job_id: single_dot
    }

    expect {
      analysis_cache.possible_paths_file(
        test_opts,
        analysis_cache.file_name(file_name: single_dot)
      )
    }.to raise_error(ArgumentError,
      'job_id must be equal to or greater than 1: .. Provided parameters: {:uuid=>"5498633d-89a7-4b65-8f4a-96aa0c09c619", :sub_folders=>["."], :file_name=>".", :job_id=>"."}')
  end
end
