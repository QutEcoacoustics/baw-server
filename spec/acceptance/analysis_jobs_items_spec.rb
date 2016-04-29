require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def analysis_jobs_id_param
  parameter :analysis_job_id, 'Analysis Job id in request url', required: true
end

def analysis_jobs_items_id_param
  analysis_jobs_id_param
  parameter :id, 'Analysis Job Item id in request url', required: true
end

def analysis_jobs_items_body_params
  parameter :status, 'Analysis Jobs Item status in request body', required: true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'AnalysisJobsItems' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # The second analysis jobs item allows us to test for different permission combinations
  # In particular we want to ensure that if someone has access to a project, then they have
  # access to the results
  let!(:second_analysis_jobs_item) {
    project = Common.create_project(other_user)
    site = Common.create_site(other_user, project)
    audio_recording = Common.create_site(owner_user, project)
    saved_search.projects << project

    Common.create_analysis_job_item(analysis_job, audio_recording)
  }

  # let(:body_attributes) {
  #   FactoryGirl.attributes_for(:analysis_jobs_item, script_id: script.id, saved_search_id: saved_search.id).to_json
  # }

  ################################
  # INDEX
  ################################

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 1
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 1
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 1
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'INDEX (as other)', :ok, {
        response_body_content: ['"total":0,', '"data":[]']
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {
        expected_json_path: get_json_error_path(:confirm)
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items' do
    analysis_jobs_id_param
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {
        expected_json_path: get_json_error_path(:sign_in)
    })
  end

  ################################
  # SHOW
  ################################

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other)', :forbidden, {
        expected_json_path: get_json_error_path(:permissions)})
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    let(:id) { analysis_jobs_item.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # SHOW - with weird permissions
  ################################



  ################################
  # UPDATE
  ################################

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/analysis_job_id'})
  end

  patch '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:patch, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/analysis_job_id'})
  end

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/analysis_job_id'})
  end

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  put '/analysis_jobs/:analysis_job_id/analysis_jobs_items/:id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:id) { analysis_jobs_item.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end


  ################################
  # FILTER
  ################################

  post '/analysis_jobs/:analysis_job_id/analysis_jobs_items/filter' do
    analysis_jobs_id_param
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

end