# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def id_params
  parameter :id, 'Question id in request url', required: true
end

def body_params
  parameter :text, 'Name of question', scope: :question, required: true
  parameter :data, 'Description of question', scope: :question
  parameter :study_ids, 'IDs of studies', scope: :question, required: true
end

def basic_filter_opts
  {
    #response_body_content: ['test question'],
    expected_json_path: ['data/0/text', 'data/0/data'],
    data_item_count: 2
  }
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Questions' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy
  create_study_hierarchy

  # Create post parameters from factory
  let(:post_attributes) { FactoryBot.attributes_for(:question, text: 'New Question text', study_ids: [study.id]) }

  # reader, writer and owner should all act the same, because questions don't derive permissions from projects
  shared_context 'Questions results' do |current_user|
    let(:current_user) { current_user }

    def token(target)
      target.send(:"#{current_user}_token")
    end

    # INDEX
    get '/questions' do
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        basic_filter_opts
      )
    end

    # CREATE
    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }
      let(:authentication_token) { token(self) }

      standard_request_options(
        :post,
        "Non-admin, including #{current_user}, cannot create",
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    # NEW
    get '/questions/new' do
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    # SHOW
    get '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    # UPDATE
    put '/questions/:id' do
      body_params
      let(:id) { question.id }
      let(:raw_post) { { question: post_attributes }.to_json }
      let(:authentication_token) { token(self) }
      standard_request_options(
        :put,
        "Non-admin, including #{current_user}, cannot update",
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    # FILTER

    post '/questions/filter' do
      let(:authentication_token) { token(self) }

      standard_request_options(
        :post,
        "Any user, including #{current_user}, can access",
        :ok,
        basic_filter_opts
      )
    end
  end

  ################################
  # INDEX
  ################################

  describe 'index' do
    get '/questions' do
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'INDEX (as admin)',
        :ok,
        basic_filter_opts.merge(data_item_count: 2)
      )
    end

    get '/questions' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'INDEX (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/questions' do
      standard_request_options(
        :get,
        'INDEX (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/questions' do
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

  describe 'create questions' do
    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :post,
        'CREATE (as admin)',
        :created,
        { expected_json_path: ['data/text', 'data/data'], response_body_content: 'New Question text' }
      )
    end

    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }
      let(:dataset_id) { dataset.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :post,
        'CREATE (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :post,
        'CREATE (invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }

      standard_request_options(
        :post,
        'CREATE (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/questions' do
      body_params
      let(:raw_post) { { 'question' => post_attributes }.to_json }
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
    get '/questions/new' do
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'NEW (as admin)',
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    get '/questions/new' do
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :get,
        'NEW (as non admin user)',
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    get '/questions/new' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'NEW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/questions/new' do
      standard_request_options(
        :get,
        'NEW (as anonymous user)',
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    get '/questions/new' do
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
    get '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'SHOW (as admin)',
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    get '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :get,
        'SHOW (as no access user)',
        :ok,
        { expected_json_path: ['data/text', 'data/data'] }
      )
    end

    get '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'SHOW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/questions/:id' do
      id_params
      let(:id) { question.id }

      standard_request_options(
        :get,
        'SHOW (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/questions/:id' do
      id_params
      let(:id) { question.id }
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

  # ################################
  # # DESTROY
  # ################################

  describe 'destroy' do
    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :delete,
        'DESTROY (as admin)',
        :no_content,
        { expected_response_has_content: false, expected_response_content_type: nil }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { owner_token }

      standard_request_options(
        :delete,
        'DESTROY (as owner user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { reader_token }

      standard_request_options(
        :delete,
        'DESTROY (as reader user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :delete,
        'DESTROY (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :delete,
        'DESTROY (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
      let(:raw_post) { { question: post_attributes }.to_json }

      standard_request_options(
        :delete,
        'DESTROY (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) }
      )
    end

    delete '/questions/:id' do
      id_params
      let(:id) { question.id }
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
    post '/questions/filter' do
      let(:authentication_token) { admin_token }

      standard_request_options(:post, 'FILTER (as admin)', :ok, basic_filter_opts)
    end

    post '/questions/filter' do
      let(:authentication_token) { no_access_token }

      standard_request_options(:post, 'FILTER (as no access user)', :ok, basic_filter_opts)
    end

    post '/questions/filter' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :post,
        'FILTER (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/questions/filter' do
      standard_request_options(
        :post,
        'FILTER (as anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/questions/filter' do
      let(:authentication_token) { harvester_token }

      standard_request_options(
        :post,
        'FILTER (with harvester token)',
        :forbidden,
        { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post '/questions/filter' do
      let(:raw_post) {
        {
          filter: {
            text: {
              starts_with: 'test question'
            }
          },
          projection: {
            include: [:text]
          }
        }.to_json
      }
      let(:authentication_token) { reader_token }

      standard_request_options(
        :post,
        'FILTER (with admin token: filter by name with projection)',
        :ok,
        {
          #response_body_content: ['Test question'],
          expected_json_path: 'data/0/text',
          data_item_count: 2
        }
      )
    end
  end

  describe 'Owner user' do
    it_behaves_like 'Questions results', :owner
  end

  describe 'Writer user' do
    it_behaves_like 'Questions results', :writer
  end

  describe 'Reader user' do
    it_behaves_like 'Questions results', :reader
  end
end
