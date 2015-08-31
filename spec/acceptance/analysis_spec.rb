require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def standard_analysis_parameters

  parameter :analysis_job_id, 'Requested analysis job id (in path/route)', required: true
  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
  parameter :results_path, 'Result file path', required: true

  let(:raw_post) { params.to_json }
end

def create_full_path(item)
  uuid = audio_recording.uuid
  top_path = File.join(analysis_cache.possible_dirs[0], 'system', uuid[0, 2].downcase, uuid.downcase)
  File.join(top_path, item)
end

def create_file(
    file = File.join('Test1', 'Test2', 'test-CASE.csv'),
    content = '"header1", "header2", "header3"\n"content1","content2", "content2"')

  full_path = create_full_path(file)
  FileUtils.mkpath File.dirname(full_path)
  File.open(full_path, 'w') { |f| f.write(content) }
end

def create_dir(dir = File.join('Test1', 'Test2'))
  full_path = create_full_path(dir)
  FileUtils.mkpath full_path
end

test_url = '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id/:results_path'

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

  context 'with empty directory' do
    before(:each) do
      create_dir
    end

    get test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/TEST2' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting empty directory incorrect case that does exist)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: ["Could not find results for job 'system' for recording ", " at 'Test1/TEST2'."]
          })
    end

    head test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/TEST2' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting empty directory incorrect case that does exist)',
          :not_found,
          {
              expected_response_has_content: false
          })
    end

    get test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting empty directory that does exist)',
          :ok,
          {
              expected_response_has_content: true,
              expected_json_path: 'meta/status',
              response_body_content: '{"meta":{"status":200,"message":"OK"},"data":{"path":"Test1/Test2","name":"Test2",type":"directory","children":[]}}'
          })

    end

    head test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting empty directory that does exist)',
          :ok,
          {
              expected_response_has_content: false
          })

    end

  end

  context 'with file' do
    before(:each) do
      create_file
    end

    get test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-case.csv' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting file in incorrect case that does exist)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: ["Could not find results for job 'system' for recording ", " at 'Test1/Test2/test-case.csv'."]
          })
    end

    head test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-case.csv' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting file in incorrect case that does exist)',
          :not_found,
          {
              expected_response_has_content: false
          })
    end

    get test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-CASE.csv' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting file in correct case that does exist)',
          :ok,
          {
              expected_response_content_type: 'text/csv',
              expected_response_has_content: true,
              response_body_content: '"header1", "header2", "header3"\n"content1","content2", "content2"'
          })
    end

    head test_url do

      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-CASE.csv' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting file in correct case that does exist)',
          :ok,
          {
              expected_response_has_content: false,
              expected_response_content_type: 'text/csv'
          })
    end

  end

  context 'with no file system changes' do
    get test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-CASE.csv' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting non-existent file)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: ["Could not find results for job 'system' for recording ", " at 'Test1/Test2/test-CASE.csv'."]
          })
    end

    head test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2/test-CASE.csv' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting non-existent file)',
          :not_found,
          {
              expected_response_has_content: false
          })
    end

    get test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting non-existent dir)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: ["Could not find results for job 'system' for recording ", " at 'Test1/Test2'."]
          })
    end

    head test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'Test1/Test2' }

      standard_request_options(
          :head,
          'ANALYSIS (as admin, requesting non-existent dir)',
          :not_found,
          {
              expected_response_has_content: false
          })
    end
  end

end