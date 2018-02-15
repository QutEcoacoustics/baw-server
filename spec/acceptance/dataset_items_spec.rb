require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def dataset_id_param
  parameter :dataset_id, 'Dataset id in request url', required: true
end

def dataset_item_id_param
  parameter :id, 'Dataset item id in request url', required: true
end

def body_params
  parameter :start_time_seconds, 'start time of dataset item', scope: :dataset_item, :required => true
  parameter :end_time_seconds, 'end time of dataset item', scope: :dataset_item, :required => true
  parameter :order, 'sort order of dataset item', scope: :dataset_item
  parameter :audio_recording_id, 'id of audio recording', scope: :dataset_item, :required => true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'DatasetItems' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # Create post parameters from factory
  # add the audio recording id as a post parameter
  let(:post_attributes) {
    post_attributes = FactoryGirl.attributes_for(:dataset_item, end_time_seconds: 234)
    post_attributes[:audio_recording_id] = audio_recording[:id]
    post_attributes
  }

  ################################
  # INDEX
  ################################

  # Expected count is 2 because of the 'default dataset', which is seed data added during a clean install.

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {expected_json_path: 'data/0/audio_recording_id', data_item_count: 1})
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {expected_json_path: 'data/0/audio_recording_id', data_item_count: 1})
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {expected_json_path: 'data/0/audio_recording_id', data_item_count: 1})
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'INDEX (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/datasets/:dataset_id/items' do
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'INDEX (as anonymous user)', :ok, {remove_auth: true, response_body_content: '200', data_item_count: 0})
  end

  ################################
  # CREATE
  ################################

  # only admin is allowed to create dataset items

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/end_time_seconds/', response_body_content: '234.0'})
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(:post, 'CREATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  # create as writer (for audio recording's project)
  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(:post, 'CREATE (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(:post, 'CREATE (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # NEW
  ################################

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'NEW (as admin)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  # since only admins can create, only admins can access new
  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'NEW (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'NEW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'NEW (as anonymous user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # SHOW
  ################################

  get '/datasets/:dataset_id/items/:id' do
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { no_access_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get, 'SHOW (an anonymous user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # UPDATE
  ################################

  # only admin can update or create

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/end_time_seconds/', response_body_content: '234.0'})
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as no access)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (as invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as not logged in)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # DESTROY
  ################################

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DELETE (as admin user)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DELETE (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DELETE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DELETE (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DELETE (as invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    standard_request_options(:delete, 'DELETE (as not logged in)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # FILTER
  ################################

  post '/dataset_items/filter' do
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'FILTER (as admin)', :ok,
                             {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'FILTER (as writer)', :ok,
                             {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'FILTER (as no access)', :ok,
                             {response_body_content: ['200'], expected_json_path: 'data', data_item_count: 0})
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'FILTER (as invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  # not logged in users can filter dataset items, but they won't get any items that they don't have permission for
  post '/dataset_items/filter' do
    standard_request_options(:post, 'FILTER (as not logged in)', :ok,
                             {response_body_content: ['200'], expected_json_path: 'data', data_item_count: 0})
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['11', '7', '100', '4']
            }
        },
        'projection' => {
            'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {
                                 expected_json_path: 'data/0/start_time_seconds',
                                 data_item_count: 1,
                                 regex_match: /"in"\:\[\"11\",\"7\",\"100\",\"[0-9]+\"\]/,
                                 response_body_content: "\"start_time_seconds\":",
                                 invalid_content: "end_time_seconds"
                             })
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['7', '100', '4']
            }
        },
        'projection' => {
            'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {
                                 expected_json_path: 'data',
                                 data_item_count: 0
                             })
  end

end