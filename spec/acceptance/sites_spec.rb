require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def sites_project_id_param
  parameter :project_id, 'Site project id in request url', required: true
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

# https://github.com/zipmark/rspec_api_documentation
resource 'Sites' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy
  
  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:site) }
  let(:post_attributes_with_lat_long) { FactoryGirl.attributes_for(:site, :with_lat_long) }

  ################################
  # INDEX
  ################################

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :ok, {expected_json_path: 'data/0/custom_latitude', data_item_count: 1})
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :ok, {expected_json_path: 'data/0/custom_latitude', data_item_count: 1})
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :ok, {expected_json_path: 'data/0/custom_latitude', data_item_count: 1})
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'INDEX (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'INDEX (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/projects/:project_id/sites' do
    sites_project_id_param
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # NEW
  ################################

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW (as admin)', :ok, {expected_json_path: 'data/longitude'})
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW (as writer)', :ok, {expected_json_path: 'data/longitude'})
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW (as reader)',:forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'NEW (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'NEW (as unconfirmed)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/projects/:project_id/sites/new' do
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { admin_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/project_ids'})
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/project_ids'})
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { other_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { unconfirmed_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (with unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  post '/projects/:project_id/sites' do
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    let(:raw_post) { {site: post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
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
    standard_request_options(:get, 'SHOW (nested route, as admin)', :ok, {expected_json_path: 'data/location_obfuscated'})
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (nested route, as writer)', :ok, {expected_json_path: 'data/location_obfuscated'})
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (nested route, as reader)', :ok, {expected_json_path: 'data/location_obfuscated'})
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (nested route, as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (nested route, as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (nested route, with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # SHALLOW SHOW
  ################################
  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (shallow route, as admin)', :ok, {expected_json_path: 'data/project_ids'})
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (shallow route, as writer)', :ok, {expected_json_path: 'data/project_ids'})
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (shallow route, as reader)', :ok, {expected_json_path: 'data/custom_longitude'})
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (shallow route, as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (shallow route, as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (shallow route, with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # latitude and longitude obfuscation
  ################################
  get '/sites/:id' do
    sites_id_param
    let(:id) { site.id }
    let(:authentication_token) { admin_token }
    check_site_lat_long_response('SHOW (shallow, latitude and longitude should NOT be obfuscated, as admin)', 200, false)
  end

  get '/projects/:project_id/sites/:id' do
    sites_project_id_param
    sites_id_param
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:authentication_token) { writer_token }
    check_site_lat_long_response('SHOW (nested, latitude and longitude should NOT be obfuscated, as writer)', 200, false)
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
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/custom_longitude'})
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/custom_longitude'})
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  put '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    sites_body_params
    let(:project_id) { project.id }
    let(:id) { site.id }
    let(:raw_post) { {site: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
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
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DESTROY (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DESTROY (unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  delete '/projects/:project_id/sites/:id' do
    sites_id_param
    sites_project_id_param
    let(:id) { site.id }
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  #####################
  # Filter
  #####################

  post '/sites/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'id' => {
                'in' => ['1', '2', '3', '4', site.id.to_s]
            }
        },
        'projection' => {
            'include' => ['id', 'name']}
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {
                                 expected_json_path: 'data/0/project_ids/0',
                                 data_item_count: 1,
                                 regex_match: /"project_ids"\:\[[0-9]+\]/,
                                 response_body_content: "\"project_ids\":[",
                                 invalid_content: ["\"project_ids\":[{\"id\":", '"description":']
                             })
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) { {
        'filter' => {
            'id' => {
                'in' => ['1', '2', '3', '4', site.id.to_s]
            }
        },
        'projection' => {
            'include' => ['id', 'name']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as writer)', :ok,
                             {
                                 expected_json_path: 'data/0/project_ids/0',
                                 data_item_count: 1,
                                 regex_match: /"project_ids"\:\[[0-9]+\]/,
                                 response_body_content: "\"project_ids\":[",
                                 invalid_content: ["\"project_ids\":[{\"id\":", '"description":']
                             })
  end

  post '/sites/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) { {
        'filter' => {
            'projects.id' => {
                'in' => [writer_permission.project.id.to_s]
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (site ids in, as writer)', :ok,
                             {
                                 expected_json_path: 'data/0/project_ids/0',
                                 data_item_count: 1,
                                 regex_match: /"project_ids"\:\[[0-9]+\]/,
                                 response_body_content: "\"project_ids\":[",
                                 invalid_content: "\"project_ids\":[{\"id\":"
                             })
  end

end