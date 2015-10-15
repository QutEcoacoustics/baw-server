require 'rails_helper'
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

  after(:each) do
    remove_media_dirs
  end

  # prepare ids needed for paths in requests below
  let(:analysis_job_id) { 'system' }

  create_entire_hierarchy

  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:audio_recording_id) { audio_recording.id }

  let(:audio_original) { BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios) }
  let(:audio_cache) { BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios) }
  let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms) }
  let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs) }

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
              response_body_content: '{"meta":{"status":200,"message":"OK"},"data":{"path":"Test1/Test2","name":"Test2","type":"directory","children":[]}}'
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

  context 'with lots of directories and files' do
    before(:each) do
      create_file(File.join('TopDir', 'one', 'two', 'three', 'four', 'five.txt'), '"five", "text"')
      create_file(File.join('TopDir', 'one', 'two', 'three', 'four', 'five', 'six.txt'), '"six", "text"')
      create_dir(File.join('TopDir', 'one1'))
      create_dir(File.join('TopDir', 'one2'))
      create_dir(File.join('TopDir', 'one3'))
      create_dir(File.join('TopDir', 'one4'))
    end

    get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting top dir with lots of directories and files)',
          :ok,
          {
              response_body_content: [
                  '{"meta":{"status":200,"message":"OK"},"data":',
                  '{"path":"/","name":"/","type":"directory","children":[',
                  '{"path":"TopDir","name":"TopDir","type":"directory","children":[',
                  '{"path":"TopDir/one","name":"one","type":"directory","children":[',
                  '{"path":"TopDir/one/two","name":"two","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three","name":"three","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four","name":"four","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five.txt","name":"five.txt","size":14,"type":"file","mime":"text/plain"}',
                  '{"path":"TopDir/one/two/three/four/five","name":"five","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five/six.txt","name":"six.txt","size":13,"type":"file","mime":"text/plain"}',
                  '{"path":"TopDir/one3","name":"one3","type":"directory","children":[]}',
                  '{"path":"TopDir/one1","name":"one1","type":"directory","children":[]}',
                  '{"path":"TopDir/one2","name":"one2","type":"directory","children":[]}',
                  '{"path":"TopDir/one4","name":"one4","type":"directory","children":[]}'
              ],
              invalid_data_content: [
                  '{"path":".","name":".","type":"directory","children":[',
                  '{"path":"..","name":"..","type":"directory","children":['
              ]

          })
    end

    get test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'TopDir' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting sub dir with lots of directories and files)',
          :ok,
          {
              response_body_content: [
                  '{"meta":{"status":200,"message":"OK"},"data":',
                  '{"path":"TopDir","name":"TopDir","type":"directory","children":[',
                  '{"path":"TopDir/one","name":"one","type":"directory","children":[',
                  '{"path":"TopDir/one/two","name":"two","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three","name":"three","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four","name":"four","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five.txt","name":"five.txt","size":14,"type":"file","mime":"text/plain"}',
                  '{"path":"TopDir/one/two/three/four/five","name":"five","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five/six.txt","name":"six.txt","size":13,"type":"file","mime":"text/plain"}',
                  '{"path":"TopDir/one3","name":"one3","type":"directory","children":[]}',
                  '{"path":"TopDir/one1","name":"one1","type":"directory","children":[]}',
                  '{"path":"TopDir/one2","name":"one2","type":"directory","children":[]}',
                  '{"path":"TopDir/one4","name":"one4","type":"directory","children":[]}'
      ]

      })
    end

    get test_url do
      standard_analysis_parameters
      let(:authentication_token) { admin_token }
      let(:results_path) { 'TopDir/one' }

      standard_request_options(
          :get,
          'ANALYSIS (as admin, requesting sub sub dir with lots of directories and files)',
          :ok,
          {
              response_body_content: [
                  '{"meta":{"status":200,"message":"OK"},"data":',
                  '{"path":"TopDir/one","name":"one","type":"directory","children":[',
                  '{"path":"TopDir/one/two","name":"two","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three","name":"three","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four","name":"four","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five.txt","name":"five.txt","size":14,"type":"file","mime":"text/plain"}',
                  '{"path":"TopDir/one/two/three/four/five","name":"five","type":"directory","children":[',
                  '{"path":"TopDir/one/two/three/four/five/six.txt","name":"six.txt","size":13,"type":"file","mime":"text/plain"}'
              ]

          })
    end

  end

end