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


  # create multiple dataset items
  #
  # In order to test get requests where the user does not have permission,
  # we include some dataset items for audio recordings that the user can not access
  #
  # After this, the dataset_items will be
  # - 1 created by the create_entire_hierarchy
  # - 1 created by create_no_access_hierarchy
  # - 1 created under a different dataset to test the dataset id path parameter
  # - 4 created with custom field values to test sorting and filtering
  # - total: 7 dataset items
  #

  create_no_access_hierarchy

  # a different dataset with one dataset item
  # to test index and filter by dataset id
  let!(:another_dataset) {
    FactoryGirl.create(:dataset, creator: admin_user)
  }

  let!(:another_dataset_item) {
    FactoryGirl.create(:dataset_item, creator: admin_user, dataset: another_dataset, audio_recording: audio_recording)
  }

  let!(:new_dataset_item) {

    FactoryGirl.create(:dataset_item,
                       creator: admin_user,
                       dataset: dataset,
                       audio_recording: audio_recording,
                       start_time_seconds: 3,
                       end_time_seconds: 4,
                       order: 1).save!

    FactoryGirl.create(:dataset_item,
                       creator: admin_user,
                       dataset: dataset,
                       audio_recording: audio_recording,
                       start_time_seconds: 1,
                       end_time_seconds: 2,
                       order: 5).save!

    FactoryGirl.create(:dataset_item,
                       creator: admin_user,
                       dataset: dataset,
                       audio_recording: audio_recording,
                       start_time_seconds: 5,
                       end_time_seconds: 6,
                       order: 2).save!

    FactoryGirl.create(:dataset_item,
                       creator: admin_user,
                       dataset: dataset,
                       audio_recording: audio_recording,
                       start_time_seconds: 8,
                       end_time_seconds: 80,
                       order: 4).save!

  }




  ################################
  # INDEX
  ################################

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'INDEX (as admin)',
        :ok,
        {expected_json_path: 'data/0/audio_recording_id', data_item_count: 6}
    )
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(:get,
                             'INDEX (as reader)',
                             :ok,
                             {expected_json_path: 'data/0/audio_recording_id', data_item_count: 5}
    )
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'INDEX (as writer)',
        :ok, {expected_json_path: 'data/0/audio_recording_id', data_item_count: 5}
    )
  end

  get '/datasets/:dataset_id/items' do
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'INDEX (with invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  get '/datasets/:dataset_id/items' do
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'INDEX (as anonymous user)',
        :ok,
        {remove_auth: true, response_body_content: '200', data_item_count: 0}
    )
  end

  ################################
  # CREATE
  ################################

  # only admin is allowed to create dataset items

  # TODO: test if returned path is correct, including correct dataset id

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(
        :post,
        'CREATE (as admin)',
        :created,
        {expected_json_path: 'data/end_time_seconds/', response_body_content: '234.0'}
    )
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(
        :post,
        'CREATE (as reader)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  # create as writer (for audio recording's project)
  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(
        :post,
        'CREATE (as writer)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(
        :post,
        'CREATE (invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  post '/datasets/:dataset_id/items' do
    body_params
    let(:raw_post) { {'dataset_item' => post_attributes}.to_json }
    let(:dataset_id) { dataset.id }
    let(:audio_recording_id) { audio_recording.id }
    standard_request_options(
        :post,
        'CREATE (as anonymous user)',
        :unauthorized,
        {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  ################################
  # NEW
  ################################

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'NEW (as admin)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'NEW (as reader)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'NEW (as writer)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/new' do
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'NEW (with invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  get '/datasets/:dataset_id/items/new' do
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'NEW (as anonymous user)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  ################################
  # SHOW
  ################################

  get '/datasets/:dataset_id/items/:id' do
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:authentication_token) { admin_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (as admin)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { no_access_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (as no access user)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { reader_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (as reader)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { writer_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (as writer)',
        :ok,
        {expected_json_path: 'data/start_time_seconds'}
    )
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:authentication_token) { invalid_token }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (with invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  get '/datasets/:dataset_id/items/:id' do
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :get,
        'SHOW (an anonymous user)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
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
    standard_request_options(
        :put,
        'UPDATE (as admin)',
        :ok,
        {expected_json_path: 'data/end_time_seconds/', response_body_content: '234.0'}
    )
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(
        :put,
        'UPDATE (as no access)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(
        :put,
        'UPDATE (as reader)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(
        :put,
        'UPDATE (as writer)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(
        :put,
        'UPDATE (as invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  put '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    body_params
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:raw_post) { {dataset_item: post_attributes}.to_json }
    standard_request_options(
        :put,
        'UPDATE (as not logged in)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
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
    standard_request_options(
        :delete,
        'DELETE (as admin user)',
        :no_content,
        {expected_response_has_content: false, expected_response_content_type: nil}
    )
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { writer_token }
    standard_request_options(
        :delete,
        'DELETE (as writer)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { reader_token }
    standard_request_options(
        :delete,
        'DELETE (as reader)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(
        :delete,
        'DELETE (as no access user)',
        :forbidden,
        {expected_json_path: get_json_error_path(:permissions)}
    )
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(
        :delete,
        'DELETE (as invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  delete '/datasets/:dataset_id/items/:id' do
    dataset_id_param
    dataset_item_id_param
    let(:id) { dataset_item.id }
    let(:dataset_id) { dataset.id }
    standard_request_options(
        :delete,
        'DELETE (as not logged in)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  ################################
  # FILTER
  ################################

  # with shallow route (no dataset id)
  post '/dataset_items/filter' do
    let(:authentication_token) { admin_token }
    standard_request_options(
        :post,
        'FILTER (as admin)',
        :ok,
        {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 7}
    )
  end

  # with deep route including dataset id
  post '/datasets/:dataset_id/dataset_items/filter' do
    dataset_id_param
    let(:dataset_id) { dataset.id }
    let(:authentication_token) { admin_token }
    standard_request_options(
        :post,
        'FILTER (as admin)',
        :ok,
        {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 6}
    )
  end

  # suppling a dataset id that doesn't have any items
  post '/datasets/:dataset_id/dataset_items/filter' do
    let(:dataset_id) { 1234567 }
    let(:authentication_token) { admin_token }
    standard_request_options(
        :post,
        'FILTER (as admin)',
        :ok,
        {response_body_content: ['200'], expected_json_path: 'data', data_item_count: 0}
        )
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { reader_token }
    standard_request_options(
        :post,
        'FILTER (as reader)',
        :ok,
        {response_body_content: ['200', '"start_time_seconds":11.0'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 6}
    )
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { writer_token }
    standard_request_options(
        :post,
        'FILTER (as writer)',
        :ok,
        {response_body_content: ['200', '11'], expected_json_path: 'data/0/start_time_seconds', data_item_count: 6}
    )
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { no_access_token }
    standard_request_options(
        :post,
        'FILTER (as no access)',
        :ok,
        {response_body_content: ['200'], expected_json_path: 'data', data_item_count: 0}
    )
  end

  post '/dataset_items/filter' do
    let(:authentication_token) { invalid_token }
    standard_request_options(
        :post,
        'FILTER (as invalid token)',
        :unauthorized,
        {expected_json_path: get_json_error_path(:sign_up)}
    )
  end

  # not logged in users can filter dataset items, but they won't get any items that they don't have permission for
  post '/dataset_items/filter' do
    standard_request_options(
        :post,
        'FILTER (as not logged in)',
        :ok,
        {response_body_content: ['200'], expected_json_path: 'data', data_item_count: 0}
    )
  end

  # start_time_seconds for the factory dataset item is within the values
  # There are 2 dataset items because there is no dataset id supplied in route params
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
    standard_request_options(
        :post,
        'FILTER (as reader)',
        :ok,
        {
            expected_json_path: 'data/0/start_time_seconds',
            data_item_count: 2,
            response_body_content: "\"start_time_seconds\":",
            invalid_content: "end_time_seconds"
        }
    )
  end

  # none of the datasets have any of those start_time_seconds
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
    standard_request_options(
        :post,
        'FILTER (as reader)',
        :ok,
        {
            expected_json_path: 'data',
            data_item_count: 0
        }
    )
  end

  # sort by virtual column
  post '/dataset_items/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['1', '3', '8']
            }
        },
        'projection' => {
            'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id', 'order']
        },
        sorting: {
            order_by: :priority,
            direction: :asc
        }
      }.to_json
    }

    example 'FILTER by start time and sort by virtual column', document: true do
      do_request
      expect(status).to eq(200)
      json = JsonSpec::Helpers::parse_json(response_body)
      expect(json['meta']['paging']['total']).to eq(3)
      expect(json['data'].size).to eq(3)
      expect(json['data'][0]['start_time_seconds']).to eq(1)
      expect(json['data'][1]['start_time_seconds']).to eq(8)
      expect(json['data'][2]['start_time_seconds']).to eq(3)
    end

  end

end