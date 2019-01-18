require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def id_params
  parameter :id, 'Study id in request url', required: true
end

def body_params
  parameter :name, 'Name of study', scope: :study, :required => true
  parameter :description, 'Description of study', scope: :study
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
  let(:post_attributes) { FactoryGirl.attributes_for(:study, name: 'New Study name') }

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
          {expected_json_path: 'data/0/name', data_item_count: 1}
      )
    end

    # writer and owner user don't need tests because studies don't derive permissions from projects

    get '/studies' do
      let(:authentication_token) { reader_token }
      standard_request_options(
          :get,
          'INDEX (as reader user)',
          :ok,
          {expected_json_path: 'data/0/name', data_item_count: 1}
      )
    end

    get '/studies' do
      let(:authentication_token) { invalid_token }
      standard_request_options(
          :get,
          'INDEX (with invalid token)',
          :unauthorized,
          {expected_json_path: get_json_error_path(:sign_up)}
      )
    end

    get '/studies' do
      standard_request_options(
          :get,
          'INDEX (as anonymous user)',
          :ok,
          {remove_auth: true, expected_json_path: 'data/0/name', data_item_count: 1}
      )
    end


    get '/studies' do
      let(:authentication_token) { harvester_token }
      standard_request_options(
          :get,
          'INDEX (as harvester)',
          :forbidden,
          {expected_json_path: get_json_error_path(:permissions)}
      )
    end

  end

  ################################
  # CREATE
  ################################

  describe 'create studies' do

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      let(:authentication_token) { admin_token }
      standard_request_options(
          :post,
          'CREATE (as admin)',
          :created,
          {expected_json_path: 'data/name', response_body_content: 'New Study name'}
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      let(:authentication_token) { reader_token }
      standard_request_options(
          :post,
          'CREATE (as reader user)',
          :created,
          {expected_json_path: 'data/name', response_body_content: 'New Study name'}
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      let(:authentication_token) { no_access_token }
      standard_request_options(
          :post,
          'CREATE (as no access user)',
          :created,
          {expected_json_path: 'data/name', response_body_content: 'New Study name'}
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      let(:authentication_token) { invalid_token }
      standard_request_options(
          :post,
          'CREATE (invalid token)',
          :unauthorized,
          {expected_json_path: get_json_error_path(:sign_up)}
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      standard_request_options(
          :post,
          'CREATE (as anonymous user)',
          :unauthorized,
          {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)}
      )
    end

    post '/studies' do
      body_params
      let(:raw_post) { {'study' => post_attributes}.to_json }
      let(:authentication_token) { harvester_token }
      standard_request_options(
          :post,
          'CREATE (as harvester user)',
          :forbidden,
          {expected_json_path: get_json_error_path(:permissions)}
      )
    end

  end

  # ################################
  # # NEW
  # ################################
  #
  # get '/studies/new' do
  #   let(:authentication_token) { admin_token }
  #   standard_request_options(
  #       :get,
  #       'NEW (as admin)',
  #       :ok,
  #       {expected_json_path: 'data/name/'}
  #   )
  # end
  #
  # get '/studies/new' do
  #   let(:authentication_token) { no_access_token }
  #   standard_request_options(
  #       :get,
  #       'NEW (as non admin user)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  # get '/studies/new' do
  #   let(:authentication_token) { invalid_token }
  #   standard_request_options(
  #       :get,
  #       'NEW (with invalid token)',
  #       :unauthorized,
  #       {expected_json_path: get_json_error_path(:sign_up)}
  #   )
  # end
  #
  # get '/studies/new' do
  #   standard_request_options(
  #       :get,
  #       'NEW (as anonymous user)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  # get '/studies/new' do
  #   let(:authentication_token) { harvester_token }
  #   standard_request_options(
  #       :get,
  #       'NEW (as harvester user)',
  #       :forbidden,
  #       {expected_json_path: get_json_error_path(:permissions)}
  #   )
  # end
  #
  # ################################
  # # SHOW
  # ################################
  #
  # get '/studies/:id' do
  #   id_params
  #   let(:id) { study.id }
  #   let(:authentication_token) { admin_token }
  #   standard_request_options(
  #       :get,
  #       'SHOW (as admin)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  # get '/studies/:id' do
  #   id_params
  #   let(:id) { study.id }
  #   let(:authentication_token) { no_access_token }
  #   standard_request_options(
  #       :get,
  #       'SHOW (as no access user)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  # get '/studies/:id' do
  #   id_params
  #   let(:id) { study.id }
  #   let(:authentication_token) { reader_token }
  #   standard_request_options(
  #       :get,
  #       'SHOW (as reader user)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  # get '/studies/:id' do
  #   id_params
  #   let(:id) { study.id }
  #   let(:authentication_token) { invalid_token }
  #   standard_request_options(
  #       :get,
  #       'SHOW (with invalid token)',
  #       :unauthorized,
  #       {expected_json_path: get_json_error_path(:sign_up)}
  #   )
  # end
  #
  # get '/studies/:id' do
  #   id_params
  #   let(:id) { study.id }
  #   standard_request_options(
  #       :get,
  #       'SHOW (an anonymous user)',
  #       :ok,
  #       {expected_json_path: 'data/name'}
  #   )
  # end
  #
  #
  # ################################
  # # UPDATE
  # ################################
  #
  #
  # # add tests for creator
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { admin_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (as admin)',
  #       :ok,
  #       {expected_json_path: 'data/name', response_body_content: 'New Study name'}
  #   )
  # end
  #
  # # owner user is the user who is the creator of the study
  # # can therefore update the study
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { owner_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (as owner user)',
  #       :ok,
  #       {expected_json_path: 'data/name', response_body_content: 'New Study name'}
  #   )
  # end
  #
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { reader_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (as reader user)',
  #       :forbidden,
  #       {expected_json_path: get_json_error_path(:permissions)}
  #   )
  # end
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { no_access_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (as no access user)',
  #       :forbidden,
  #       {expected_json_path: get_json_error_path(:permissions)}
  #   )
  # end
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { invalid_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (with invalid token)',
  #       :unauthorized,
  #       {expected_json_path: get_json_error_path(:sign_up)}
  #   )
  # end
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (as anonymous user)',
  #       :unauthorized,
  #       {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)}
  #   )
  # end
  #
  # put '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:raw_post) { {study: post_attributes}.to_json }
  #   let(:authentication_token) { harvester_token }
  #   standard_request_options(
  #       :put,
  #       'UPDATE (with harvester token)',
  #       :forbidden,
  #       {expected_json_path: get_json_error_path(:permissions)}
  #   )
  # end
  #
  # ################################
  # # DESTROY
  # ################################
  #
  # # Destroy is not implemented, so just one test for expected 404
  # delete '/studies/:id' do
  #   body_params
  #   let(:id) { study.id }
  #   let(:authentication_token) { admin_token }
  #   standard_request_options(
  #       :delete,
  #       'DESTROY (as admin)',
  #       :not_found,
  #       {expected_json_path: 'meta/error/info/original_route', response_body_content: 'Could not find'}
  #   )
  # end
  #
  # ################################
  # # FILTER
  # ################################
  #
  #
  # # Basic filter with no conditions is expected count is 2 because of the 'default study'.
  # # The 'default study' exists as seed data in a clean install
  # # for no filter constraints, use the following opts
  # basic_filter_opts = {
  #     response_body_content: ['The default study', 'gen_study'],
  #     expected_json_path: 'data/0/name',
  #     data_item_count: 2
  # }
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { admin_token }
  #   standard_request_options(:post,'FILTER (as admin)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { owner_token }
  #   standard_request_options(:post,'FILTER (as owner user)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { writer_token }
  #   standard_request_options(:post,'FILTER (as writer user)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { reader_token }
  #   standard_request_options(:post,'FILTER (as reader user)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { no_access_token }
  #   standard_request_options(:post,'FILTER (as no access user)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { invalid_token }
  #   standard_request_options(
  #       :post,
  #       'FILTER (with invalid token)',
  #       :unauthorized,
  #       {expected_json_path: get_json_error_path(:sign_up)}
  #   )
  # end
  #
  # post '/studies/filter' do
  #   standard_request_options(:post,'FILTER (as anonymous user)',:ok, basic_filter_opts)
  # end
  #
  # post '/studies/filter' do
  #   let(:authentication_token) { harvester_token }
  #   standard_request_options(
  #       :post,
  #       'FILTER (with harvester token)',
  #       :forbidden,
  #       {response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions)}
  #   )
  # end
  #
  # post '/studies/filter' do
  #   let(:raw_post) {
  #     {
  #         filter: {
  #             name: {
  #                 eq: 'default'
  #             }
  #         }
  #         # projection: {
  #         #     include: [:name, :description]
  #         # }
  #     }.to_json
  #   }
  #   let(:authentication_token) { reader_token }
  #   standard_request_options(
  #       :post,
  #       'FILTER (with admin token: filter by name with projection)',
  #       :ok,
  #       {
  #           response_body_content: ['The default study'],
  #           expected_json_path: 'data/0/name',
  #           data_item_count: 1
  #       }
  #   )
  # end


end