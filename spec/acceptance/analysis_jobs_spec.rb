require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def analysis_jobs_id_param
  parameter :id, 'Analysis Job id in request url', required: true
end

def analysis_jobs_body_params
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

  let(:body_attributes) { FactoryGirl.attributes_for(:analysis_job, script_id: script.id, saved_search_id: saved_search.id).to_json }

  ################################
  # INDEX
  ################################

  get '/analysis_jobs' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {expected_json_path: 'data/0/saved_search_id', data_item_count: 1})
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
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'INDEX (as other)', :ok, {response_body_content: ['"total":0,', '"data":[]']})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/analysis_jobs' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # SHOW
  ################################

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # NEW
  ################################

  get '/analysis_jobs/new' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
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
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'NEW (as other)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'NEW (as unconfirmed)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/analysis_jobs/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # CREATE
  ################################

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/saved_search_id'})
  end

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { other_token }
    standard_request_options(:post, 'CREATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  post '/analysis_jobs' do
    analysis_jobs_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # UPDATE
  ################################

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  patch '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:patch, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/saved_search_id'})
  end

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  put '/analysis_jobs/:id' do
    analysis_jobs_id_param
    analysis_jobs_body_params
    let(:id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # DESTROY
  ################################

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DESTROY (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DESTROY (unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  delete '/analysis_jobs/:id' do
    analysis_jobs_id_param
    let(:id) { analysis_job.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
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
        response_body_content: '"saved_searches.stored_query":{"contains":"blah"}'
    })
  end

end