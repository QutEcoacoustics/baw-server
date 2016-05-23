require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def analysis_jobs_id_param
  parameter :analysis_job_id, 'Analysis Job id in request url', required: true
end

def analysis_jobs_items_id_param
  analysis_jobs_id_param
  parameter :audio_recording_id, 'Audio Recording id in request url', required: true
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
    project = Creation::Common.create_project(other_user)
    site = Creation::Common.create_site(other_user, project)
    audio_recording = Creation::Common.create_audio_recording(owner_user, owner_user, site)
    saved_search.projects << project

    Creation::Common.create_analysis_job_item(analysis_job, audio_recording)
  }

  # Create another audio recording that is NOT in any analysis_jobs_items.
  # Used for testing SYSTEM endpoints.
  let!(:system_audio_recording) {
    Creation::Common.create_audio_recording(owner_user, owner_user, site)
  }

  # only the harvester can update
  let!(:harvester_user) { FactoryGirl.create(:harvester) }
  let!(:harvester_token) { Creation::Common.create_user_token(harvester_user) }

  let(:body_attributes) {
    FactoryGirl.attributes_for(:analysis_jobs_item,
                               analysis_job_id: analysis_job.id,
                               audio_recording_id: audio_recording.id
    ).to_json
  }

  ################################
  # INDEX
  ################################

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {
        expected_json_path: [
            'data/0/analysis_job_id',
            'data/0/audio_recording_id',
            'data/1/analysis_job_id',
            'data/1/audio_recording_id'
        ],
        data_item_count: 2
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { writer_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 1
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { reader_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 1
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { other_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as other)', :ok, {
        response_body_content: ['"total":0,', '"data":[]']
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { unconfirmed_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {
        expected_json_path: get_json_error_path(:confirm)
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { invalid_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {
        expected_json_path: get_json_error_path(:sign_in)
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    let(:authentication_token) { admin_token }
    let(:analysis_job_id) { 'system' }
    standard_request_options(:get, 'INDEX system (admin token)', :ok, {
        expected_json_path: ['data/0/analysis_job_id', 'data/0/audio_recording_id'],
        data_item_count: 3,
        response_body_content: ['"audio_recording_id":%{audio_recording_id}']
    },
    &proc { |context, opts|
     opts[:response_body_content][0] = opts[:response_body_content][0] % {
         audio_recording_id: context.system_audio_recording.id
     }
    })
  end

  ################################
  # Index - with weird permissions
  # Any user should have access to a result if they have access to a project
  ################################

  get '/analysis_jobs/:analysis_job_id/audio_recordings' do
    analysis_jobs_id_param
    # this user has access to both projects
    let(:authentication_token) { other_token }
    let(:analysis_job_id) { analysis_job.id }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {
        expected_json_path: [
            'data/0/analysis_job_id',
            'data/0/audio_recording_id',
            'data/1/analysis_job_id',
            'data/1/audio_recording_id'
        ],
        data_item_count: 2
    })
  end

  ################################
  # SHOW
  ################################

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }

    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other)', :forbidden, {
        expected_json_path: get_json_error_path(:permissions)})
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  get '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }

    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {
        expected_json_path: ['data/analysis_job_id', 'data/audio_recording_id']
    })
  end


  ################################
  # UPDATE
  ################################

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {
        expected_json_path: 'data/analysis_job_id'
    })
  end

  patch '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { harvester_token }
    standard_request_options(:patch, 'UPDATE (as harvester)', :ok, {
        expected_json_path: 'data/analysis_job_id'
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, {
        expected_json_path: get_json_error_path(:permissions)
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {
        expected_json_path: get_json_error_path(:permissions)
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other)', :forbidden, {
        expected_json_path: get_json_error_path(:permissions)
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {
        expected_json_path: get_json_error_path(:confirm)
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (invalid token)', :unauthorized, {
        expected_json_path: get_json_error_path(:sign_up)
    })
  end

  put '/analysis_jobs/:analysis_job_id/audio_recordings/:audio_recording_id' do
    analysis_jobs_items_id_param
    analysis_jobs_items_body_params
    let(:audio_recording_id) { analysis_jobs_item.id }
    let(:analysis_job_id) { 'system' }
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE system (as admin)', :method_not_allowed, {
        response_body_content: '"info":{"available_methods":["GET","HEAD","OPTIONS"]}}}'
    })
  end


  ################################
  # FILTER
  ################################

  post '/analysis_jobs/:analysis_job_id/audio_recordings/filter' do
    analysis_jobs_id_param
    let(:authentication_token) { reader_token }
    let(:analysis_job_id) { analysis_job.id }
    let(:raw_post) {
      {
          filter: {
              status: {
                  eq: 'working'
              }
          },
          projection: {
              include: %w(analysis_job_id, audio_recording_id, status)
          }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
        expected_json_path: 'meta/filter/status',
        data_item_count: 1,
        response_body_content: ['"status":{"eq":"working"']
    })
  end

  post '/analysis_jobs/:analysis_job_id/audio_recordings/filter' do
    analysis_jobs_id_param
    let(:authentication_token) { reader_token }
    let(:analysis_job_id) { 'system' }
    let(:raw_post) {
      {
          filter: {
              status: {
                  eq: 'working'
              }
          },
          projection: {
              include: %w(analysis_job_id, audio_recording_id, status)
          }
      }.to_json
    }
    standard_request_options(:post, 'FILTER system (as reader) - using non-existent properties', :not_acceptable, {
        expected_json_path: ['meta/filter/status', 'meta/error/detail'],
        data_item_count: 0,
        response_body_content: ['"not acceptable"']
    })
  end

  post '/analysis_jobs/:analysis_job_id/audio_recordings/filter' do
    analysis_jobs_id_param
    let(:authentication_token) { reader_token }
    let(:analysis_job_id) { 'system' }
    let(:raw_post) {
      {
          filter: {
              'audio_recording.duration_seconds': {
                  gt: 7200
              }
          },
          projection: {
              include: %w(analysis_job_id, audio_recording_id, status)
          }
      }.to_json
    }
    standard_request_options(:post, 'FILTER system (as reader)', :ok, {
        expected_json_path: 'meta/filter/status',
        data_item_count: 1,
        response_body_content: ['"audio_recording.duration_seconds":{"gt":7200']
    })
  end
end