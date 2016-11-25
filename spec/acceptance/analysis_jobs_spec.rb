require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def id_params
  parameter :id, 'Analysis Job id in request url', required: true
end

def body_params
  parameter :script_id, 'Analysis Job script id in request body', required: true
  parameter :saved_search_id, 'Analysis Job saved search id in request body', required: true

  parameter :name, 'Analysis Job name in request body', required: true
  parameter :annotation_name, 'Analysis Job annotation name in request body', required: false
  parameter :custom_settings, 'Analysis Job custom settings in request body', required: true
  parameter :description, 'Analysis Job description in request body', required: false
end

# https://github.com/zipmark/rspec_api_documentation
resource 'AnalysisJobs' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  let(:body_attributes) {
    FactoryGirl
        .attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id)
        .except(:started_at, :overall_progress,
                :overall_progress_modified_at, :overall_count,
                :overall_duration_seconds, :overall_data_length_bytes)
        .to_json
  }

  let(:body_attributes_update) {
    FactoryGirl
        .attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id)
        .slice(:name, :description)
        .to_json
  }


  ################################
  # INDEX
  ################################

  get '/analysis_jobs' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {expected_json_path: 'data/0/saved_search_id', data_item_count: 1})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'INDEX (as owner)', :ok, {expected_json_path: 'data/0/saved_search_id', data_item_count: 1})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {expected_json_path: 'data/0/saved_search_id', data_item_count: 1})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {expected_json_path: 'data/0/saved_search_id', data_item_count: 1})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'INDEX (as no access user)', :ok, {response_body_content: ['"total":0,', '"data":[]']})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  get '/analysis_jobs' do
    standard_request_options(:get, 'INDEX (as anonymous user)', :ok, {remove_auth: true, response_body_content: ['"total":0,', '"data":[]']})
  end

  ################################
  # SHOW
  ################################

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'SHOW (as owner)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { 'system' }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW system (as admin)', :not_implemented, {
        response_body_content: '"error":{"details":"The service is not ready for use"'
    })
  end

  get '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    standard_request_options(:get, 'SHOW (as anonymous user)', :unauthorized, {
        remove_auth: true,
        expected_json_path: get_json_error_path(:sign_in)
    })
  end

  ################################
  # NEW
  ################################

  get '/analysis_jobs/new' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'NEW (as owner)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW (as reader)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'NEW (as no access)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/analysis_jobs/new' do
    standard_request_options(:get, 'NEW (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # CREATE
  ################################

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { owner_token }
    standard_request_options(:post, 'CREATE (as owner)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  post '/analysis_jobs' do
    body_params
    let(:raw_post) { body_attributes }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  post '/analysis_jobs' do
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
          "name" => "job test creation",
          "custom_settings" => "#custom settings 267",
          "script_id" => 999899,
          "saved_search_id" => 99989,
          "format" => "json",
          "controller" => "analysis_jobs",
          "action" => "create",
          "analysis_job" =>
              {
                  "name" => "job test creation",
                  "custom_settings" => "#custom settings 267",
                  "script_id" => 999899,
                  "saved_search_id" => 99989
              }

      }.to_json }
    let!(:preparation_create) {
      project = Creation::Common.create_project(writer_user)
      script = FactoryGirl.create(:script, creator: writer_user, id: 999899)

      saved_search = FactoryGirl.create(:saved_search, creator: writer_user, id: 99989)
      saved_search.projects << project
      saved_search.save!
      saved_search
    }
    standard_request_options(:post, 'CREATE (as writer, testing projects error)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  ################################
  # UPDATE
  ################################

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes_update }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  patch '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes_update }
    let(:authentication_token) { admin_token }
    standard_request_options(:patch, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes_update }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as no access)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  put '/analysis_jobs/:id' do
    id_params
    let(:id) { 'system' }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE system (as admin)', :method_not_allowed, {
        response_body_content: '"info":{"available_methods":["GET","HEAD","OPTIONS"]}}}'
    })
  end

  put '/analysis_jobs/:id' do
    id_params
    body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    standard_request_options(:put, 'UPDATE (as anonymous user)', :unauthorized, {
        remove_auth: true,
        expected_json_path: get_json_error_path(:sign_up)})
  end

  describe 'update special case - retrying the job' do
    def set_completed
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'completed')
      AnalysisJobsItem.update_all status: :failed
    end

    # special case - retrying the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_completed
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'processing'}}.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (retry job, as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
    end

    # special case - retrying the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_completed
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'processing'}}.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (retry job,  writer)', :ok, {expected_json_path: 'data/saved_search_id'})
    end
  end

  describe 'update special case - pausing the job' do
    def set_processing
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'processing')
      #AnalysisJobsItem.update_all status: :failed
    end

    # special case - pausing the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_processing
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'suspended'}}.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (pause job, as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
    end

    # special case - pausing the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_processing
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'suspended'}}.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (pause job,  writer)', :ok, {expected_json_path: 'data/saved_search_id'})
    end
  end


  describe 'update special case - resuming the job' do
    def set_suspended
      # low-level modify factory item's state to make this test work
      analysis_job.update_column(:overall_status, 'suspended')
      #AnalysisJobsItem.update_all status: :failed
    end

    # special case - resuming the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_suspended
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'processing'}}.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(:put, 'UPDATE (pause job, as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
    end

    # special case - resuming the job
    put '/analysis_jobs/:id' do
      id_params
      parameter :overall_status, 'Analysis Job script id in request body', required: true
      let(:id) {
        # hack: insert here for correct execution time
        set_suspended
        analysis_job.id
      }
      let(:raw_post) { {analysis_job: {overall_status: 'processing'}}.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(:put, 'UPDATE (pause job,  writer)', :ok, {expected_json_path: 'data/saved_search_id'})
    end
  end

  ################################
  # DESTROY
  ################################

  def mock_processing_state(opts)
    analysis_job.update_columns(
        overall_status: 'processing',
        overall_status_modified_at: Time.zone.now,
        started_at: Time.zone.now
    )
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { admin_token }
    standard_request_options(
        :delete,
        'DESTROY (as admin)',
        :no_content,
        {
            expected_response_has_content: false,
            expected_response_content_type: nil
        },
        &:mock_processing_state
    )
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(
        :delete,
        'DESTROY (as writer, when [:processing|:suspended|:complete])',
        :no_content,
        {
            expected_response_has_content: false,
            expected_response_content_type: nil
        },
        &:mock_processing_state)
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer, when [:new|:preparing])', :conflict, {
        expected_json_path: 'meta/error/details',
        response_body_content: '"message":"Conflict"'
    })
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { 'system' }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY system (as admin)', :method_not_allowed, {
        response_body_content: '"info":{"available_methods":["GET","HEAD","OPTIONS"]}}}'
    })
  end

  delete '/analysis_jobs/:id' do
    id_params
    let(:id) { analysis_job.id }
    standard_request_options(:delete, 'DESTROY (as anonymous user)', :unauthorized, {
        remove_auth: true,
        expected_json_path: get_json_error_path(:sign_up)
    })
  end

  ################################
  # FILTER
  ################################

  post '/analysis_jobs/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        filter: {
            'saved_searches.stored_query' => {
                contains: 'blah'
            }
        },
        projection: {
            include: %w(id name saved_search_id)
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
        expected_json_path: 'meta/filter/saved_searches.stored_query',
        data_item_count: 1,
        response_body_content: ['"saved_searches.stored_query":{"contains":"blah"}'],
        invalid_content: ['"saved_search":', '"script":']
    })
  end

  post '/analysis_jobs/filter' do
    let(:authentication_token) { no_access_token }
    let(:raw_post) { {
        filter: {
            name: {
                contains: 'name'
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as no access user)', :ok, {
        response_body_content: [
            '{"meta":{"status":200,"message":"OK","filter":{"name":{"contains":"name"}},',
            '"paging":{"page":1,"items":25,"total":0,"max_page":0,'],
        data_item_count: 0,
    })
  end

end