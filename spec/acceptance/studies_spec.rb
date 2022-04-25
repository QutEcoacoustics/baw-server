# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def id_params
  parameter :id, 'Study id in request url', required: true
end

def body_params
  parameter :name, 'Name of study', scope: :study, required: true
  parameter :description, 'Description of study', scope: :study
  parameter :dataset_id, 'ID of dataset', scope: :study, required: true
end

def basic_filter_opts
  {
    #response_body_content: ['test study'],
    expected_json_path: 'data/0/name',
    data_item_count: 1
  }
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Studies' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy
  create_study_hierarchy

  # Create post parameters from factory
  let(:post_attributes) { FactoryBot.attributes_for(:study, name: 'New Study name', dataset_id: dataset.id) }

  # reader, writer and owner should all act the same, because studies don't derive permissions from projects
  shared_context 'Studies results' do |current_user|
    let(:current_user) { current_user }

    def token(target)
      target.send("#{current_user}_token".to_sym)
    end

    # INDEX
    get '/studies' do
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        { expected_json_path: 'data/0/name', data_item_count: 1 }
      )
    end

    # CREATE
    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }
      let(:authentication_token) { token(self) }

      standard_request_options(
        :post,
        "Non-admin, including #{current_user}, cannot create",
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    # NEW
    get '/studies/new' do
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    # SHOW
    get '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { token(self) }

      standard_request_options(
        :get,
        "Any user, including #{current_user}, can access",
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    # UPDATE
    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      let(:authentication_token) { token(self) }
      standard_request_options(
        :put,
        "Non-admin, including #{current_user}, cannot update",
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    # FILTER

    post '/studies/filter' do
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
    get '/studies' do
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'INDEX (as admin)',
        :ok,
        { expected_json_path: 'data/0/name', data_item_count: 1 }
      )
    end

    get '/studies' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'INDEX (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/studies' do
      standard_request_options(
        :get,
        'INDEX (as anonymous user)',
        :ok,
        { remove_auth: true, expected_json_path: 'data/0/name', data_item_count: 1 }
      )
    end

    get '/studies' do
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

  describe 'create studies' do
    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :post,
        'CREATE (as admin)',
        :created,
        { expected_json_path: 'data/name', response_body_content: 'New Study name' }
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }
      let(:dataset_id) { dataset.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :post,
        'CREATE (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :post,
        'CREATE (invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }

      standard_request_options(
        :post,
        'CREATE (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { { 'study' => post_attributes }.to_json }
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
    get '/studies/new' do
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'NEW (as admin)',
        :ok,
        { expected_json_path: 'data/name/' }
      )
    end

    get '/studies/new' do
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :get,
        'NEW (as non admin user)',
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    get '/studies/new' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'NEW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/studies/new' do
      standard_request_options(
        :get,
        'NEW (as anonymous user)',
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    get '/studies/new' do
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
    get '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :get,
        'SHOW (as admin)',
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    get '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :get,
        'SHOW (as no access user)',
        :ok,
        { expected_json_path: 'data/name' }
      )
    end

    get '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :get,
        'SHOW (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    get '/studies/:id' do
      id_params
      let(:id) { study.id }

      standard_request_options(
        :get,
        'SHOW (an anonymous user)',
        :ok,
        { expected_json_path: 'data/name' }
      )
    end
  end
  #
  # ################################
  # # UPDATE
  # ################################

  describe 'update' do
    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(
        :put,
        'UPDATE (as admin)',
        :ok,
        { expected_json_path: 'data/name', response_body_content: 'New Study name' }
      )
    end

    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      let(:authentication_token) { no_access_token }
      standard_request_options(
        :put,
        'UPDATE (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      let(:authentication_token) { invalid_token }
      standard_request_options(
        :put,
        'UPDATE (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      standard_request_options(
        :put,
        'UPDATE (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) }
      )
    end

    put '/studies/:id' do
      body_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }
      let(:authentication_token) { harvester_token }
      standard_request_options(
        :put,
        'UPDATE (with harvester token)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  # ################################
  # # DESTROY
  # ################################

  describe 'destroy' do
    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { admin_token }

      standard_request_options(
        :delete,
        'DESTROY (as admin)',
        :no_content,
        { expected_response_has_content: false, expected_response_content_type: nil }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { owner_token }

      standard_request_options(
        :delete,
        'DESTROY (as owner user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { reader_token }

      standard_request_options(
        :delete,
        'DESTROY (as reader user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :delete,
        'DESTROY (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :delete,
        'DESTROY (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
      let(:raw_post) { { study: post_attributes }.to_json }

      standard_request_options(
        :delete,
        'DESTROY (as anonymous user)',
        :unauthorized,
        { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) }
      )
    end

    delete '/studies/:id' do
      id_params
      let(:id) { study.id }
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
    post '/studies/filter' do
      let(:authentication_token) { admin_token }

      standard_request_options(:post, 'FILTER (as admin)', :ok, basic_filter_opts)
    end

    post '/studies/filter' do
      let(:authentication_token) { no_access_token }

      standard_request_options(:post, 'FILTER (as no access user)', :ok, basic_filter_opts)
    end

    post '/studies/filter' do
      let(:authentication_token) { invalid_token }

      standard_request_options(
        :post,
        'FILTER (with invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post '/studies/filter' do
      standard_request_options(:post, 'FILTER (as anonymous user)', :ok, basic_filter_opts)
    end

    post '/studies/filter' do
      let(:authentication_token) { harvester_token }

      standard_request_options(
        :post,
        'FILTER (with harvester token)',
        :forbidden,
        { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post '/studies/filter' do
      let(:raw_post) {
        {
          filter: {
            name: {
              starts_with: 'test study'
            }
          },
          projection: {
            include: [:name]
          }
        }.to_json
      }
      let(:authentication_token) { reader_token }

      standard_request_options(
        :post,
        'FILTER (with admin token: filter by name with projection)',
        :ok,
        {
          #response_body_content: ['Test study'],
          expected_json_path: 'data/0/name',
          data_item_count: 1
        }
      )
    end
  end

  describe 'Owner user' do
    it_behaves_like 'Studies results', :owner
  end

  describe 'Writer user' do
    it_behaves_like 'Studies results', :writer
  end

  describe 'Reader user' do
    it_behaves_like 'Studies results', :reader
  end
end
