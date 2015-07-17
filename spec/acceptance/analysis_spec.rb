require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def standard_analysis_parameters

  parameter :analysis_job_id, 'Requested analysis job id (in path/route)', required: true
  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
  parameter :results_path, 'Result file path', required: true

  let(:raw_post) { params.to_json }
end

resource 'Analysis' do
  header 'Authorization', :authentication_token

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
    @admin_user = FactoryGirl.create(:admin)
  end

  after(:each) do
    remove_media_dirs
  end

  # prepare ids needed for paths in requests below
  let(:analysis_job_id) { 'system' }
  let(:project_id) { @write_permission.project.id }
  let(:site_id) { @write_permission.project.sites[0].id }
  let(:audio_recording_id) { @write_permission.project.sites[0].audio_recordings[0].id }
  let(:audio_recording) { @write_permission.project.sites[0].audio_recordings[0] }
  let(:audio_event) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0] }

  let(:audio_original) { BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios) }
  let(:audio_cache) { BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios) }
  let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms) }
  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs) }

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:invalid_token) { "Token token=\"blah blah blah\"" }

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do
    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test/test-CASE.csv' }
    standard_request_options(
        :get,
        'ANALYSIS (as admin, requesting file that does not exist)',
        :not_found,
        {
            expected_json_path: 'meta/error/details',
            response_body_content: ["Could not find results for job 'system' for recording "," in 'Test/test-CASE.csv'."]
        })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do
    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test/test-case.csv' }
    let(:include_test_file) { true }

    standard_request_options(
        :get,
        'ANALYSIS (as admin, requesting file case sensitivity that does exist)',
        :not_found,
        {
            expected_json_path: 'meta/error/details',
            response_body_content: ["Could not find results for job 'system' for recording "," in 'Test/test-CASE.csv'."]
        })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do

    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test/test-CASE.csv' }
    let(:include_test_file) { true }

    standard_request_options(
        :get,
        'ANALYSIS (as admin, requesting GET file that does exist)',
        :ok,
        {
            expected_response_content_type: 'text/csv',
            expected_response_has_content: true,
            response_body_content: '{"content":"This is some content."}'
        })
  end

  head '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do

    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test/test-CASE.csv' }
    let(:include_test_file) { true }

    standard_request_options(
        :head,
        'ANALYSIS (as admin, requesting HEAD file that does exist)',
        :ok,
        {
            expected_response_content_type: 'text/csv',
            expected_response_has_content: false
        })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do

    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test' }
    let(:include_test_file) { true }

    standard_request_options(
        :get,
        'ANALYSIS (as admin, requesting GET directory that does exist)',
        :ok,
        {
            expected_response_content_type: 'text/csv',
            expected_response_has_content: true,
            response_body_content: '{"content":"This is some content."}'
        })
  end

  head '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path' do

    standard_analysis_parameters
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    let(:results_path) { 'Test' }
    let(:include_test_file) { true }

    standard_request_options(
        :head,
        'ANALYSIS (as admin, requesting HEAD directory that does exist)',
        :ok,
        {
            expected_response_content_type: 'text/csv',
            expected_response_has_content: false
        })
  end
end