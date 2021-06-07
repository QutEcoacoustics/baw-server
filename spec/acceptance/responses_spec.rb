# frozen_string_literal: true


require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def id_params
  parameter :id, 'Response id in request url', required: true
end

def body_params
  parameter :text, 'Name of response', scope: :response, required: true
  parameter :data, 'Description of response', scope: :response
  parameter :study_ids, 'IDs of studies', scope: :response, required: true
end

def basic_filter_opts
  {
    #response_body_content: ['test response'],
    expected_json_path: ['data/0/data'],
    data_item_count: 1
  }
end

# response body content is compared against unparsed json response, so json values
# in the response data are escaped
response_body_content = '"data":"{\"labels_present\": [1,2]}\n"'
created_response_body_content = '"data":"{\\"test_name\\":\\"test value\\"}'

# https://github.com/zipmark/rspec_api_documentation
resource 'Responses' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy
  create_study_hierarchy

  # Create post parameters from factory
  let(:post_attributes) {
    FactoryBot.attributes_for(:response,
                              data: { test_name: 'test value' }.to_json,
                              study_id: study.id,
                              question_id: question.id,
                              dataset_item_id: dataset_item.id)
  }

  ################################
  # INDEX
  ################################

  describe 'index' do
    get '/responses' do
      let(:authentication_token) { admin_token }
      standard_request_options(
        :get,
        'INDEX (as admin)',
        :ok,
        basic_filter_opts
      )
    end

    # admin or response creator can read
    # reader user was the creator of the test response

    get '/responses' do
      let(:authentication_token) { owner_token }
      standard_request_options(
        :get,
        'INDEX (as non-responder (owner))',
        :ok,
        { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
      )
    end

    get '/responses' do
      let(:authentication_token) { writer_token }
      standard_request_options(
        :get,
        'INDEX (as non-responder (writer))',
        :ok,
        { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
      )
    end

    get '/responses' do
      let(:authentication_token) { reader_token }
      standard_request_options(
        :get,
        'INDEX (as responder (reader))',
        :ok,
        basic_filter_opts
      )
    end

    get '/responses' do
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :get,
        'INDEX (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/responses' do
      standard_request_options(
        :get,
        'INDEX (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/responses' do
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :get,
        'INDEX (as harvester)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  ################################
  # CREATE
  ################################

  describe 'create responses' do
    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(
        :post,
        'CREATE (as admin)',
        :created,
        # json data string will be escaped because it gets compared against unparsed response body
        { expected_json_path: ['data/data'], response_body_content: created_response_body_content }
      )
    end

    # must have read permission on to create response.

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { owner_token }
      standard_request_options(
        :post,
        'CREATE (as owner of project via dataset item)',
        :created,
        { expected_json_path: ['data/data'], response_body_content: created_response_body_content }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(
        :post,
        'CREATE (as writer of project via dataset item)',
        :created,
        { expected_json_path: ['data/data'], response_body_content: created_response_body_content }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { reader_token }
      standard_request_options(
        :post,
        'CREATE (as reader of project via dataset item)',
        :created,
        { expected_json_path: ['data/data'], response_body_content: created_response_body_content }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:dataset_id) { dataset.id }
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :post,
        'CREATE (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :post,
        'CREATE (invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      standard_request_options(
        :post,
        'CREATE (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/responses' do
      body_params
      let(:raw_post) { { 'response' => post_attributes }.to_json }
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :post,
        'CREATE (as harvester user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  # ################################
  # # NEW
  # ################################

  describe 'new' do
    get '/responses/new' do
      let(:authentication_token) { admin_token }
      standard_request_options(
        :get,
        'NEW (as admin)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { owner_token }
      standard_request_options(
        :get,
        'NEW (as owner)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { writer_token }
      standard_request_options(
        :get,
        'NEW (as writer)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { reader_token }
      standard_request_options(
        :get,
        'NEW (as reader)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :get,
        'NEW (as non admin user)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :get,
        'NEW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/responses/new' do
      standard_request_options(
        :get,
        'NEW (as anonymous user)',
        :ok,
        { expected_json_path: 'data/data' }
      )
    end

    get '/responses/new' do
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :get,
        'NEW (as harvester user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  # ################################
  # # SHOW
  # ################################

  describe 'show' do
    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { admin_token }
      standard_request_options(
        :get,
        'SHOW (as admin)',
        :ok,
        { expected_json_path: 'data/data', response_body_content: response_body_content }
      )
    end

    # admin or response creator can read
    # reader user was the creator of the test response

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { owner_token }
      standard_request_options(
        :get,
        'INDEX (as non-responder (owner))',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { writer_token }
      standard_request_options(
        :get,
        'INDEX (as non-responder (writer))',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { reader_token }
      standard_request_options(
        :get,
        'INDEX (as responder (reader))',
        :ok,
        { expected_json_path: 'data/data', response_body_content: response_body_content }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :get,
        'SHOW (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :get,
        'SHOW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      standard_request_options(
        :get,
        'SHOW (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :get,
        'SHOW (as harvester)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end
  #
  # ################################
  # # UPDATE
  # ################################

  describe 'update' do
    method_not_allowed_content = 'HTTP method not allowed for this resource.'

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(
        :put,
        'UPDATE (as admin)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { owner_token }
      standard_request_options(
        :put,
        'UPDATE (as owner user)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { writer_token }
      standard_request_options(
        :put,
        'UPDATE (as writer user)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { reader_token }
      standard_request_options(
        :put,
        'UPDATE (as reader user)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :put,
        'UPDATE (as no access user)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :put,
        'UPDATE (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      standard_request_options(
        :put,
        'UPDATE (as anonymous user)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end

    put '/responses/:id' do
      body_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :put,
        'UPDATE (with harvester token)',
        :method_not_allowed,
        { response_body_content: method_not_allowed_content }
      )
    end
  end

  # ################################
  # # DESTROY
  # ################################

  describe 'destroy' do
    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { admin_token }
      standard_request_options(
        :delete,
        'DESTROY (as admin)',
        :no_content,
        { expected_response_has_content: false, expected_response_content_type: nil }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { owner_token }
      standard_request_options(
        :delete,
        'DESTROY (as owner user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { reader_token }
      standard_request_options(
        :delete,
        'DESTROY (as reader user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :delete,
        'DESTROY (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :delete,
        'DESTROY (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:raw_post) { { response: post_attributes }.to_json }
      standard_request_options(
        :delete,
        'DESTROY (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) }
      )
    end

    delete '/responses/:id' do
      id_params
      let(:id) { user_response.id }
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :delete,
        'DESTROY (with harvester token)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  # ################################
  # # FILTER
  # ################################

  describe 'filter' do
    post '/responses/filter' do
      let(:authentication_token) { admin_token }
      standard_request_options(:post, 'FILTER (as admin)', :ok, basic_filter_opts)
    end

    post '/responses/filter' do
      let(:authentication_token) { owner_token }
      standard_request_options(
        :post,
        'FILTER (as owner user)',
        :ok,
        { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
      )
    end

    post '/responses/filter' do
      let(:authentication_token) { writer_token }
      standard_request_options(
        :post,
        'FILTER (as no writer user)',
        :ok,
        { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
      )
    end

    post '/responses/filter' do
      let(:authentication_token) { reader_token }
      standard_request_options(:post, 'FILTER (as no access user)', :ok, basic_filter_opts)
    end

    post '/responses/filter' do
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :post,
        'FILTER (as no access user)',
        :ok,
        { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
      )
    end

    post '/responses/filter' do
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :post,
        'FILTER (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/responses/filter' do
      standard_request_options(
        :post,
        'FILTER (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/responses/filter' do
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :post,
        'FILTER (with harvester token)',
        :forbidden,
        { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
      )
    end

    describe 'temp' do
      post '/responses/filter' do
        let(:raw_post) {
          {
            filter: {
              data: {
                starts_with: '{'
              }
            },
            projection: {
              include: [:data]
            }
          }.to_json
        }
        let(:authentication_token) { reader_token }
        standard_request_options(
          :post,
          'FILTER (with admin token: filter by name with projection)',
          :ok,
          {
            #response_body_content: ['Test response'],
            expected_json_path: 'data/0/data',
            data_item_count: 1
          }
        )
      end
    end
  end
end
