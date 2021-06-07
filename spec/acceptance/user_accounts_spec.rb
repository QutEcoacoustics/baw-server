# frozen_string_literal: true


require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def id_param
  parameter :id, 'Requested user ID (in path/route)', required: true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Users' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # prepare ids needed for paths in requests below
  let(:admin_id) { admin_user.id }
  let(:owner_id) { owner_user.id }
  let(:writer_id) { writer_user.id }
  let(:reader_id) { reader_user.id }
  let(:no_access_id) { no_access_user.id }

  # Create post parameters from factory
  let(:post_attributes) {
    post_attrs = FactoryBot.attributes_for(:user)
    post_attrs.delete(:authentication_token)
    post_attrs
  }

  # CREATE does not make sense for user_accounts -
  # account creation is done by devise/registrations#create

  ################################
  # INDEX
  ################################
  get '/user_accounts' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'INDEX (as admin)', :not_acceptable, {
      expected_json_path: 'meta/error/details',
      response_body_content: ['"This resource is not available in this format \'application/json\'."']
    })
  end

  get '/user_accounts' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'INDEX (as owner)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/user_accounts' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'INDEX (as writer)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/user_accounts' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'INDEX (as reader)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/user_accounts' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'INDEX (as no access user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/user_accounts' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'INDEX (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/user_accounts' do
    standard_request_options(:get, 'INDEX (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # SHOW (does not need to test every permission - not related to project permissions)
  ################################

  get '/user_accounts/:id' do
    id_param
    let(:id) { admin_id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin, same user)', :ok, { expected_json_path: 'data/user_name' })
  end

  get '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'SHOW (as owner, different user)', :ok, { expected_json_path: 'data/user_name' })
  end

  get '/user_accounts/:id' do
    id_param
    let(:id) { no_access_id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user, same user)', :ok, { expected_json_path: 'data/user_name' })
  end

  get '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user, different user)', :ok, { expected_json_path: 'data/user_name' })
  end

  get '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    standard_request_options(:get, 'SHOW (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # UPDATE (does not need to test every permission - not related to project permissions)
  ################################
  put '/user_accounts/:id' do
    id_param
    let(:id) { admin_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin, same user)', :ok, { expected_json_path: 'data/user_name' })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { reader_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin, different user)', :ok, { expected_json_path: 'data/user_name' })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { writer_token } # admin only, users edit using devise/registrations#edit
    standard_request_options(:put, 'UPDATE (as writer, same user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { reader_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { reader_token } # admin only, users edit using devise/registrations#edit
    standard_request_options(:put, 'UPDATE (as reader, same user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { no_access_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer, different user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/user_accounts/:id' do
    id_param
    let(:id) { writer_id }
    let(:raw_post) { { user: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # MY ACCOUNT
  ################################

  get '/my_account' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'MY ACCOUNT (as reader)', :ok, { expected_json_path: 'data/user_name' })
  end

  get '/my_account' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'MY ACCOUNT (invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/my_account' do
    standard_request_options(:get, 'MY ACCOUNT (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # UPDATE PREFERENCES
  ################################

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'USER PREFS (as admin)', :ok, { expected_json_path: 'data/preferences/volume' })
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'USER PREFS (as reader)', :ok, { expected_json_path: 'data/preferences/volume' })
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'USER PREFS (as no access user)', :ok, { expected_json_path: 'data/preferences/volume' })
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'USER PREFS (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    standard_request_options(:put, 'USER PREFS (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume": 1, "muted": false, "auto_play": false, "visualize": {"hide_images": true, "hide_fixed": false}}' }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'modify writer preferences - complex object', :ok, {
      expected_json_path: [
        'data/preferences/volume',
        'data/preferences/visualize',
        'data/preferences/visualize/hide_fixed'
      ]
    })
  end

  ################################
  # FILTER
  ################################

  post '/user_accounts/filter' do
    let!(:update_site_tz) {
      writer_user.tzinfo_tz = 'Australia/Sydney'
      writer_user.rails_tz = 'Sydney'
      writer_user.save!
    }
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => [writer_id]
          }
        },
        'projection' => {
          'include' => [:id, :user_name]
        }
      }.to_json
    }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'FILTER (as reader checking timezone info)', :ok, {
      expected_json_path: ['data/0/user_name', 'meta/projection/include', 'data/0/timezone_information'],
      data_item_count: 1,
      response_body_content: '"timezone_information":{"identifier_alt":"Sydney","identifier":"Australia/Sydney","friendly_identifier":"Australia - Sydney","utc_offset":'
    })
  end

  post '/user_accounts/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => [writer_id]
          }
        },
        'projection' => {
          'include' => [:id, :user_name]
        }
      }.to_json
    }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'FILTER (as reader checking no timezone info)', :ok, {
      expected_json_path: ['data/0/user_name', 'meta/projection/include', 'data/0/timezone_information'],
      data_item_count: 1,
      response_body_content: '"timezone_information":null'
    })
  end

  post '/user_accounts/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => [writer_id]
          }
        },
        'projection' => {
          'include' => [:id, :user_name]
        }
      }.to_json
    }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'FILTER (as admin)', :ok, {
      expected_json_path: ['data/0/user_name', 'meta/projection/include'],
      data_item_count: 1,
      response_body_content: ['"last_seen_at":null,"preferences":null']
    })
  end

  post '/user_accounts/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => [writer_id, reader_id, admin_id]
          }
        }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  post '/user_accounts/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'id' => {
            'in' => [writer_id, reader_id, admin_id]
          }
        }
      }.to_json
    }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'FILTER (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end
end
