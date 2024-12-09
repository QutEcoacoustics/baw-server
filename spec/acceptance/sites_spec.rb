# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def sites_project_id_param
  parameter :project_ids, 'Site project id in request url', required: true
end

def sites_id_param
  parameter :id, 'Site id in request url', required: true
end

def sites_body_params
  parameter :name, 'Site name in request body', required: true
  parameter :description, 'Analysis Job annotation name in request body', required: false
  parameter :longitude, 'Analysis Job custom settings in request body', required: false
  parameter :latitude, 'Analysis Job description in request body', required: false
  parameter :notes, 'Analysis Job description in request body', required: false
  parameter :image, 'Analysis Job description in request body', required: false
  parameter :tzinfo_tz, 'Analysis Job description in request body', required: false
  parameter :rails_tz, 'Analysis Job description in request body', required: false
end

def expected_paths
  [
    'id',
    'name',
    'description',
    'creator_id',
    'updater_id',
    'created_at',
    'updated_at',
    'project_ids',
    'location_obfuscated',
    'custom_latitude',
    'custom_longitude',
    'timezone_information',
    'description_html',
    'image_urls'
  ].map { |path| "data/0/#{path}" }
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Sites' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # Create post parameters from factory
  let(:post_attributes) { FactoryBot.attributes_for(:site).except(:projects).merge(project_ids: [project.id]) }
  let(:post_attributes_with_lat_long) { FactoryBot.attributes_for(:site, :with_lat_long) }

  ################################
  # SHALLOW INDEX
  ################################

  get '/sites' do
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'INDEX (shallow route, as admin)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/sites' do
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'INDEX (shallow route, as owner)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/sites' do
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'INDEX (shallow route, as writer)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/sites' do
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'INDEX (shallow route, as reader)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/sites' do
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'INDEX (shallow route, has parameters, as reader)', :ok,
      expected_json_path: expected_paths, data_item_count: 1)
  end

  get '/sites' do
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'INDEX (shallow route, invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_in))
  end

  get '/sites' do
    standard_request_options(:get, 'INDEX (shallow route, as anonymous user)', :ok,
      remove_auth: true, response_body_content: '200', data_item_count: 0)
  end

  ################################
  # INDEX
  ################################

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'INDEX (as admin)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'INDEX (as owner)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'INDEX (as writer)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'INDEX (as reader)', :ok,
      expected_json_path: 'data/0/custom_latitude', data_item_count: 1)
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'INDEX (has parameters, as reader)', :ok,
      expected_json_path: expected_paths, data_item_count: 1)
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'INDEX (as other)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_in))
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }

    standard_request_options(:get, 'INDEX (as anonymous user)', :unauthorized,
      remove_auth: true, expected_json_path: get_json_error_path(:sign_in))
  end

  ################################
  # NEW
  ################################

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'NEW (as admin)', :ok, expected_json_path: 'data/longitude')
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'NEW (as owner)', :ok, expected_json_path: 'data/longitude')
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'NEW (as writer)', :ok, expected_json_path: 'data/longitude')
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'NEW (as reader)', :ok, expected_json_path: 'data/longitude')
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'NEW (as no access user)', :ok, expected_json_path: 'data/longitude')
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'NEW (invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }

    standard_request_options(:get, 'NEW (as anonymous user)', :ok, expected_json_path: 'data/longitude')
  end

  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as admin)', :created, expected_json_path: 'data/project_ids')
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { owner_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as owner)', :created, expected_json_path: 'data/project_ids')
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as writer)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as reader)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { no_access_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as other)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    let(:raw_post) { { site: post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as anonymous user', :unauthorized, remove_auth: true,
      expected_json_path: get_json_error_path(:sign_up))
  end

  ################################
  # NESTED SHOW
  ################################
  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'SHOW (nested route, as admin)', :ok, expected_json_path: 'data/location_obfuscated')
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'SHOW (nested route, as owner)', :ok, expected_json_path: 'data/location_obfuscated')
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (nested route, as writer)', :ok,
      expected_json_path: 'data/location_obfuscated')
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (nested route, as reader)', :ok,
      expected_json_path: 'data/location_obfuscated')
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'SHOW (nested route, as other)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'SHOW (nested route, with invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }

    standard_request_options(:get, 'SHOW (nested route, as anonymous user)', :unauthorized, remove_auth: true,
      expected_json_path: get_json_error_path(:sign_up))
  end

  ################################
  # SHALLOW SHOW
  ################################
  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'SHOW (shallow route, as admin)', :ok, expected_json_path: 'data/project_ids')
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'SHOW (shallow route, as owner)', :ok, expected_json_path: 'data/project_ids')
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (shallow route, as writer)', :ok, expected_json_path: 'data/project_ids')
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (shallow route, as reader)', :ok, expected_json_path: 'data/custom_longitude')
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'SHOW (shallow route, as reader)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'SHOW (shallow route, with invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }

    standard_request_options(:get, 'SHOW (shallow route, as anonymous user)', :unauthorized, remove_auth: true,
      expected_json_path: get_json_error_path(:sign_up))
  end

  ################################
  # latitude and longitude obfuscation
  ################################
  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { admin_token }

    check_site_lat_long_response('SHOW (shallow, latitude and longitude should NOT be obfuscated, as admin)', 200,
      false)
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { writer_token }

    check_site_lat_long_response('SHOW (nested, latitude and longitude should NOT be obfuscated, as writer)', 200,
      false)
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { reader_token }

    check_site_lat_long_response('SHOW (shallow, latitude and longitude should be obfuscated, as reader)', 200, true)
  end

  ################################
  # UPDATE
  ################################
  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, expected_json_path: 'data/custom_longitude')
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:put, 'UPDATE (as owner)', :ok, expected_json_path: 'data/custom_longitude')
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { { site: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user)', :unauthorized, remove_auth: true,
      expected_json_path: get_json_error_path(:sign_up))
  end

  ################################
  # DESTROY
  ################################

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }

    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, expected_response_has_content: false,
      expected_response_content_type: nil)
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { owner_token }

    standard_request_options(:delete, 'DESTROY (as owner)', :no_content, expected_response_has_content: false,
      expected_response_content_type: nil)
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }

    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }

    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(:delete, 'DESTROY (as other)', :forbidden,
      expected_json_path: get_json_error_path(:permissions))
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(:delete, 'DESTROY (invalid token)', :unauthorized,
      expected_json_path: get_json_error_path(:sign_up))
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }

    standard_request_options(:delete, 'DESTROY (as anonymous user)', :unauthorized, remove_auth: true,
      expected_json_path: get_json_error_path(:sign_up))
  end

  #####################
  # SHALLOW Filter
  #####################

  post '/sites/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => ['1', '2', '3', '4', site.id.to_s]
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (shallow route, as reader)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: ['"project_ids":[{"id":', '"description":']
    )
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => ['1', '2', '3', '4', site.id.to_s]
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (shallow route, as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: ['"project_ids":[{"id":', '"description":']
    )
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'projects.id' => {
            'in' => [writer_permission.project.id.to_s]
          }
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (shallow route, project ids, as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: '"project_ids":[{"id":'
    )
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'audio_recordings.id' => {
            'eq' => site.audio_recordings.first.id.to_s
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (shallow route, audio recordings id, as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"data":\[\{"id":[0-9]+,"name":"site name [0-9]+","project_ids":\[[0-9]+\]/,
      response_body_content: '"projection":{"include":["id","name"]}',
      invalid_content: '"project_ids":[{"id":'
    )
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let!(:update_site_tz) {
      site2 = Creation::Common.create_site(writer_user, project)
      site2.tzinfo_tz = 'Australia/Sydney'
      site2.rails_tz = 'Sydney'
      site2.save!
    }
    let(:raw_post) {
      {
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (shallow route, as writer checking for timezone info)', :ok,
      expected_json_path: ['data/0/project_ids/0', 'data/0/timezone_information'],
      data_item_count: 2,
      response_body_content: '"timezone_information":{"identifier_alt":"Sydney","identifier":"Australia/Sydney","friendly_identifier":"Australia - Sydney","utc_offset":'
    )
  end

  #####################
  # Filter
  #####################

  post '/projects/:project_id/sites/filter' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => ['1', '2', '3', '4', site.id.to_s]
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (as reader)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: ['"project_ids":[{"id":', '"description":']
    )
  end

  post '/projects/:project_id/sites/filter' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => ['1', '2', '3', '4', site.id.to_s]
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: ['"project_ids":[{"id":', '"description":']
    )
  end

  post '/projects/:project_id/sites/filter' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'projects.id' => {
            'in' => [writer_permission.project.id.to_s]
          }
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (project ids, as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"project_ids":\[[0-9]+\]/,
      response_body_content: '"project_ids":[',
      invalid_content: '"project_ids":[{"id":'
    )
  end

  post '/projects/:project_id/sites/filter' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let(:raw_post) {
      {
        'filter' => {
          'audio_recordings.id' => {
            'eq' => site.audio_recordings.first.id.to_s
          }
        },
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (audio recordings id, as writer)', :ok,
      expected_json_path: 'data/0/project_ids/0',
      data_item_count: 1,
      regex_match: /"data":\[\{"id":[0-9]+,"name":"site name [0-9]+","project_ids":\[[0-9]+\]/,
      response_body_content: '"projection":{"include":["id","name"]}',
      invalid_content: '"project_ids":[{"id":'
    )
  end

  post '/projects/:project_id/sites/filter' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let!(:update_site_tz) {
      site2 = Creation::Common.create_site(writer_user, project)
      site2.tzinfo_tz = 'Australia/Sydney'
      site2.rails_tz = 'Sydney'
      site2.save!
    }
    let(:raw_post) {
      {
        'projection' => {
          'include' => ['id', 'name']
        }
      }.to_json
    }

    standard_request_options(
      :post, 'FILTER (as writer checking for timezone info)', :ok,
      expected_json_path: ['data/0/project_ids/0', 'data/0/timezone_information'],
      data_item_count: 2,
      response_body_content: '"timezone_information":{"identifier_alt":"Sydney","identifier":"Australia/Sydney","friendly_identifier":"Australia - Sydney","utc_offset":'
    )
  end
end
