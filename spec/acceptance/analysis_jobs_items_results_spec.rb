# frozen_string_literal: true

require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'
require 'fixtures/fixtures'

#
# This file contains tests for the #show endpoint for the AnalysisJobsItems controller
#

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

DEFAULT_CREATE_FILE = File.join('Test1', 'Test2', 'test-CASE.csv')

def create_file(
  file = DEFAULT_CREATE_FILE,
  content = '"header1", "header2", "header3"\n"content1","content2", "content2"')

  full_path = create_full_path(file)
  FileUtils.mkpath File.dirname(full_path)
  File.open(full_path, 'w') { |f| f.write(content) }
end

# We want to be able serve files out of an Sqlite3 file as if it were just a directory
# This is the fixture that we will use to test this feature
SQLITE_FIXTURE = Fixtures.sqlite_fixture.basename.to_s
def copy_sqlite_file
  full_path = create_full_path(SQLITE_FIXTURE)
  FileUtils.mkpath File.dirname(full_path)

  FileUtils.copy(Fixtures.sqlite_fixture, full_path)
end

DEFAULT_CREATE_DIR = File.join('Test1', 'Test2')
def create_dir(dir = DEFAULT_CREATE_DIR)
  full_path = create_full_path(dir)
  FileUtils.mkpath full_path
end

def template_object(object, key, hash, array_index = nil)
  return if object.nil? || object[key].nil?

  if object[key].kind_of?(Array)
    object[key].each_index do |index|
      object[key][index] = object[key][index] % hash if array_index.nil? || array_index == index
    end
  else
    object[key] = object[key] % hash
  end
end

def insert_audio_recording_id(context, opts, array_index = 1)
  hash = {audio_recording_id: context.audio_recording.id}

  template_object(opts, :response_body_content, hash, array_index)
end

def insert_audio_recording_ids(context, opts, hash_extend = {})
  hash = {
      audio_recording_id_1: context.analysis_jobs_item.audio_recording_id,
      audio_recording_id_2: context.second_analysis_jobs_item.audio_recording_id
  }.merge(hash_extend)

  template_object(opts, :response_body_content, hash)
  template_object(opts, :invalid_data_content, hash)
end

def paging_helper(total = 0, max_page = 1, page = 1, items = 25)
  ',' \
      + '"paging":{"page":' + page.to_s \
      + ',"items":' + items.to_s \
      + ',"total":' + total.to_s \
      + ',"max_page":' + max_page.to_s \
      + ',"current":'
end

test_url = "/analysis_jobs/:analysis_job_id/results/:audio_recording_id/:results_path"

resource 'AnalysisJobsItemsResults' do

  shared_examples_for 'AnalysisJobsItems results' do |current_user|

    header 'Authorization', :authentication_token
    header 'Accept', 'application/json'

    after(:each) do
      remove_media_dirs
    end

    # prepare ids needed for paths in requests below
    let(:analysis_job_id) { 'system' }

    create_entire_hierarchy

    let!(:second_analysis_jobs_item) {
      audio_recording_2 = Creation::Common.create_audio_recording(writer_user, writer_user, site)

      Creation::Common.create_analysis_job_item(analysis_job, audio_recording_2)
    }

    let(:project_id) { project.id }
    let(:site_id) { site.id }
    let(:audio_recording_id) { audio_recording.id }

    let(:audio_original) { BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios) }
    let(:audio_cache) { BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios) }
    let(:spectrogram_cache) { BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms) }
    let(:analysis_cache) { BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs) }

    let(:current_user) { current_user }

    def token(target)
      target.send((current_user.to_s + '_token').to_sym)
    end

    context 'with root results, fake directories' do
      # url without '/:audio_recording_id/:results_path'
      get test_url.chomp('/:audio_recording_id/:results_path') do
        parameter :analysis_job_id, 'Requested analysis job id (in path/route)', required: true
        let(:authentication_token) {
          token(self)
        }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting root results directory)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    '"paging":{"page":1,"items":25,"total":2,"max_page":1,',
                    '{"analysis_job_id":"system"',
                    '"path":"/analysis_jobs/system/results/","name":"results","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/","name":"%{audio_recording_id_1}","type":"directory","has_children":true',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_2}/","name":"%{audio_recording_id_2}","type":"directory","has_children":true'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end


      # url without '/:audio_recording_id/:results_path'
      get test_url.chomp('/:audio_recording_id/:results_path') do
        parameter :analysis_job_id, 'Requested analysis job id (in path/route)', required: true
        parameter :page, 'The page of results', required: true
        parameter :items, 'The page of results', required: true

        let(:authentication_token) {
          token(self)
        }

        let(:page) { 2 }
        let(:items) { 1 }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting root results directory, with paging params)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    '"paging":{"page":2,"items":1,"total":2,"max_page":2,',
                    '{"analysis_job_id":"system"',
                    '"path":"/analysis_jobs/system/results/","name":"results","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_2}/","name":"%{audio_recording_id_2}","type":"directory","has_children":true'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end
    end

    context 'with audio_recording results, no directory' do
      get test_url do
        standard_analysis_parameters
        let(:authentication_token) {
          token(self)
        }
        let(:results_path) { '' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting audio_recording, empty results_path)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(0, 0, 1, 25),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/","name":"%{audio_recording_id_1}","type":"directory","children":['
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      # url without '/:results_path'
      get test_url.chomp('/:results_path') do
        standard_analysis_parameters
        let(:authentication_token) {
          token(self)
        }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting audio_recording, no results_path))',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(0, 0, 1, 25),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/","name":"%{audio_recording_id_1}","type":"directory","children":['
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end
    end

    context 'with empty directory' do
      before(:each) do
        create_dir
      end

      get test_url do

        standard_analysis_parameters
        let(:authentication_token) {
          token(self)
        }
        let(:results_path) { 'Test1/TEST2' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting empty directory incorrect case that does exist)',
            :not_found,
            {
                expected_json_path: 'meta/error/details',
                response_body_content: ["Could not find results directory for analysis job 'system' for recording ", " at 'Test1/TEST2'."]
            })
      end

      head test_url do

        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/TEST2' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting empty directory incorrect case that does exist)',
            :not_found,
            {
                expected_response_has_content: false
            })
      end

      get test_url do

        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting empty directory that does exist)',
            :ok,
            {
                expected_response_has_content: true,
                expected_json_path: 'meta/status',
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(0, 0),
                    '"data":{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/Test1/Test2/","name":"Test2","type":"directory","children":[]}}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      head test_url do

        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting empty directory that does exist)',
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
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-case.csv' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in incorrect case that does exist)',
            :not_found,
            {
                expected_json_path: 'meta/error/details',
                response_body_content: ["Could not find results directory for analysis job 'system' for recording ", " at 'Test1/Test2/test-case.csv'."]
            })
      end

      head test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-case.csv' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in incorrect case that does exist)',
            :not_found,
            {
                expected_response_has_content: false
            })
      end

      get test_url do

        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-CASE.csv' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in correct case that does exist)',
            :ok,
            {
                expected_response_content_type: 'text/csv',
                expected_response_has_content: true,
                response_body_content: '"header1", "header2", "header3"\n"content1","content2", "content2"'
            })
      end

      head test_url do

        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-CASE.csv' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in correct case that does exist)',
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
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-CASE.csv' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting non-existent file)',
            :not_found,
            {
                expected_json_path: 'meta/error/details',
                response_body_content: ["Could not find results directory for analysis job 'system' for recording ", " at 'Test1/Test2/test-CASE.csv'."]
            })
      end

      head test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2/test-CASE.csv' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting non-existent file)',
            :not_found,
            {
                expected_response_has_content: false
            })
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting non-existent dir)',
            :not_found,
            {
                expected_json_path: 'meta/error/details',
                response_body_content: ["Could not find results directory for analysis job 'system' for recording ", " at 'Test1/Test2'."]
            })
      end

      head test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'Test1/Test2' }

        standard_request_options(
            :head,
            'ANALYSIS (as ' + current_user.to_s + ', requesting non-existent dir)',
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

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { '' }

        # noinspection RubyLiteralArrayInspection
        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting top dir with lots of directories and files)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(1),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/","name":"%{audio_recording_id_1}","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/","name":"TopDir","type":"directory","has_children":true',
                ],
                invalid_data_content: [
                    '{"path":".","name":".","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/./","name":".","type":"directory","children":[',
                    '{"path":"..","name":"..","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/../","name":"..","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/","name":"TopDir","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/","name":"one","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/","name":"two","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/","name":"three","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/","name":"four","type":"directory","children":[',
                    '{"name":"five.txt","size_bytes":14,"type":"file","mime":"text/plain"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/five/","name":"five","type":"directory","children":[',
                    '{"name":"six.txt","size_bytes":13,"type":"file","mime":"text/plain"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one3/","name":"one3","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one1/","name":"one1","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one2/","name":"one2","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one4/","name":"one4","type":"directory","children":[]}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'TopDir' }

        parameter :page, 'The page of results', required: true
        parameter :items, 'The number of results per page', required: true

        let(:page) { 2 }
        let(:items) { 2 }

        # one
        # one1
        # one2 <--
        # one3 <--
        # one4
        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sub dir with lots of directories and files, with paging params)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(5, 3, 2, 2),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/","name":"TopDir","type":"directory","children":[',

                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one2/","name":"one2","type":"directory","has_children":false}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one3/","name":"one3","type":"directory","has_children":false}',
                ],
                invalid_data_content:[
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/","name":"one","type":"directory","has_children":true',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one1/","name":"one1","type":"directory","has_children":false}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one4/","name":"one4","type":"directory","has_children":false}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'TopDir' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sub dir with lots of directories and files)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(5),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/","name":"TopDir","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/","name":"one","type":"directory","has_children":true',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one3/","name":"one3","type":"directory","has_children":false}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one1/","name":"one1","type":"directory","has_children":false}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one2/","name":"one2","type":"directory","has_children":false}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one4/","name":"one4","type":"directory","has_children":false}'
                ],
                invalid_data_content: [
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/","name":"one","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/","name":"two","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/","name":"three","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/","name":"four","type":"directory","children":[',
                    '{"name":"five.txt","size_bytes":14,"type":"file","mime":"text/plain"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/five/","name":"five","type":"directory","children":[',
                    '{"name":"six.txt","size_bytes":13,"type":"file","mime":"text/plain"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one3/","name":"one3","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one1/","name":"one1","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one2/","name":"one2","type":"directory","children":[]}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one4/","name":"one4","type":"directory","children":[]}'
                ]

            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'TopDir/one' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sub sub dir with lots of directories and files)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(1),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/","name":"one","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/","name":"two","type":"directory","has_children":true'
                ],
                invalid_data_content: [
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/","name":"two","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/","name":"three","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/","name":"four","type":"directory","children":[',
                    '{"name":"five.txt","size_bytes":14,"type":"file","mime":"text/plain"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/five/","name":"five","type":"directory","children":[',
                    '{"name":"six.txt","size_bytes":13,"type":"file","mime":"text/plain"}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { 'TopDir/one/two/three/four' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sub sub dir with files)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(2),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/","name":"four","type":"directory","children":[',
                    '{"mime":"text/plain","name":"five.txt","size_bytes":14,"type":"file"}',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/four/five/","name":"five","type":"directory","has_children":true}'
                ],
                invalid_data_content: [
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/","name":"two","type":"directory","children":[',
                    '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/TopDir/one/two/three/","name":"three","type":"directory","children":[',
                    '{"name":"six.txt","size_bytes":13,"type":"file","mime":"text/plain"}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

    end

    context 'dot files are not included' do

      before do
        create_file('.test-dot-file', '')
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { '' }

        standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting top dir ensuring no dot files)',
            :ok,
            {
                response_body_content: [
                    '{"meta":{"status":200,"message":"OK"',
                    paging_helper(0, 0),
                    '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                    '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/","name":"%{audio_recording_id_1}","type":"directory","children":['
                ],
                invalid_data_content: [
                    '{"name":".test-dot-file","type":"file","size_bytes":0,"mime":""}'
                ]
            },
            &proc { |context, opts| insert_audio_recording_ids context, opts }
        )
      end

    end

    context 'escaping result dir is not not possible' do
      before do
        File.open(Dir.home + '/home-file.png', 'w') { |f| f.write('') }
        create_file('/../parent-file.png', '')

        path = create_full_path('../parent-file.png')
        unless File.exist?(path)
          raise "parent-file not found"
        end

        path2 = Dir.home + '/home-file.png'
        unless File.exist?(path2)
          raise "home-file not found"
        end
      end

      after do
        File.delete(Dir.home + '/home-file.png')
        File.delete(create_full_path('../parent-file.png'))
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { '../parent-file.png' }

        standard_request_options(
          :get,
          'ANALYSIS (as ' + current_user.to_s + ', requesting file above result root fails)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: [
                "Could not find the requested item: Could not find results directory for analysis job 'system' for recording",
                " at '../parent-file.png'."
              ]
          }
        )
      end

      get test_url do
        standard_analysis_parameters
        let(:authentication_token) { token(self) }
        let(:results_path) { '~/parent-file.png' }

        standard_request_options(
          :get,
          'ANALYSIS (as ' + current_user.to_s + ', requesting file above result root fails)',
          :not_found,
          {
              expected_json_path: 'meta/error/details',
              response_body_content: [
                "Could not find the requested item: Could not find results directory for analysis job 'system' for recording",
                " at '~/parent-file.png'."
              ]
          }
        )
      end

    end

    context 'reading from sqlite3 files' do
      before(:each) do
        copy_sqlite_file
      end

      context 'sqlite individual files' do
        get test_url do

          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          let(:results_path) { SQLITE_FIXTURE + '/BLENDED.Tile_20160727T110000Z_120.png'}

          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in sqlite file acts like a file request)',
            :ok,
            {
              expected_response_content_type: 'image/png',
              expected_response_has_content: true,
              # PNG magic header
              response_body_content: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("c*")
            })
        end

        get test_url do

          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          let(:results_path) { SQLITE_FIXTURE + '/sub_dir_2/BLENDED.Tile_20160727T123000Z_7.5.png'}

          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file (in sub directory) in sqlite file acts like a file request)',
            :ok,
            {
              expected_response_content_type: 'image/png',
              expected_response_has_content: true,
              # PNG magic header
              response_body_content: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].pack("c*")
            })
        end

        get test_url do
          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          # The `blended` part of the path is not lowercase in the fixture - this tests 404 and case sensitivity
          let(:results_path) { SQLITE_FIXTURE + '/sub_dir_2/blended.Tile_20160727T123000Z_7.5.png'}

          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting file in incorrect case that does exist)',
            :not_found,
            {
              expected_json_path: 'meta/error/details',
              response_body_content: [
                  "Could not find results directory for analysis job 'system' for recording '",
                  " at '#{SQLITE_FIXTURE}/sub_dir_2/blended.Tile_20160727T123000Z_7.5.png'."
              ]
            })
        end

        get test_url do
          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          # The `SUB` part of the path is not uppercase in the fixture - this tests 404 and case sensitivity
          let(:results_path) { SQLITE_FIXTURE + '/SUB_dir_2/BLENDED.Tile_20160727T123000Z_7.5.png'}

          standard_request_options(
              :get,
              'ANALYSIS (as ' + current_user.to_s + ', requesting file in directory in incorrect case that does exist)',
              :not_found,
              {
                  expected_json_path: 'meta/error/details',
                  response_body_content: [
                      "Could not find results directory for analysis job 'system' for recording ",
                      " at '#{SQLITE_FIXTURE}/SUB_dir_2/BLENDED.Tile_20160727T123000Z_7.5.png'."
                  ]
              })
        end
      end

      context 'sqlite directory listings' do
        get test_url do
          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          let(:results_path) { SQLITE_FIXTURE }

          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sqlite file should act like dir listing)',
            :ok,
            {
              response_body_content: [
                '{"meta":{"status":200,"message":"OK"',
                paging_helper(7),
                '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                '{"mime":"image/png","name":"BLENDED.Tile_20160727T110000Z_240.png","size_bytes":4393,"type":"file"}',

                '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/%{sqlite3_file}/sub_dir_1/","name":"sub_dir_1","type":"directory","has_children":true',
                '{"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/%{sqlite3_file}/sub_dir_2/","name":"sub_dir_2","type":"directory","has_children":true',
              ],
              invalid_data_content: [
              ]
            },
            &proc { |context, opts|
              insert_audio_recording_ids context, opts, { sqlite3_file: SQLITE_FIXTURE }
            }
          )
        end

        get test_url do
          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          let(:results_path) { "IDontExist.sqlite3" }

          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sqlite file that does not exist)',
            :not_found,
            {
              expected_json_path: 'meta/error/details',
              response_body_content: [
                "Could not find results directory for analysis job 'system' for recording '",
                " at 'IDontExist.sqlite3'."
              ]
            }
          )
        end

        get test_url do
          standard_analysis_parameters
          let(:authentication_token) { token(self) }
          let(:results_path) { SQLITE_FIXTURE + '/sub_dir_1' }

          parameter :page, 'The page of results', required: true
          parameter :items, 'The number of results per page', required: true

          let(:page) { 2 }
          let(:items) { 1 }

          # - `example__Tiles.sqlite3/sub_dir_1/BLENDED.Tile_20160727T122624Z_3.2.png`
          # - `example__Tiles.sqlite3/sub_dir_1/BLENDED.Tile_20160727T123600Z_3.2.png` <-- this one
          # - `example__Tiles.sqlite3/sub_dir_1/BLENDED.Tile_20160727T124536Z_3.2.png`
          standard_request_options(
            :get,
            'ANALYSIS (as ' + current_user.to_s + ', requesting sub dir in sqlite file, with paging params)',
            :ok,
            {
              response_body_content: [
                '{"meta":{"status":200,"message":"OK"',
                paging_helper(3, 3, 2, 1),
                '{"id":null,"analysis_job_id":"system","audio_recording_id":%{audio_recording_id_1},',
                '"path":"/analysis_jobs/system/results/%{audio_recording_id_1}/%{sqlite3_file}/sub_dir_1/","name":"sub_dir_1","type":"directory","children":[',

                '{"mime":"image/png","name":"BLENDED.Tile_20160727T123600Z_3.2.png","size_bytes":97722,"type":"file"}',
              ],
              invalid_data_content:[
                'BLENDED.Tile_20160727T124536Z_3.2.png',
                'BLENDED.Tile_20160727T122624Z_3.2.png',
              ]
            },
            &proc { |context, opts|
              insert_audio_recording_ids context, opts, { sqlite3_file: SQLITE_FIXTURE }
            }
          )
        end
      end

    end
  end

  describe 'Admin user' do
    it_should_behave_like 'AnalysisJobsItems results', :admin
  end

  describe 'Writer user' do
    it_should_behave_like 'AnalysisJobsItems results', :writer
  end

  describe 'Reader user' do
    it_should_behave_like 'AnalysisJobsItems results', :reader
  end

end
