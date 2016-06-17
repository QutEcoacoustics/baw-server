require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Users' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # prepare ids needed for paths in requests below
  let(:writer_id) { writer_user.id }
  let(:reader_id) { reader_user.id }
  let(:other_id) { other_user.id }
  let(:admin_id) { admin_user.id }

  # Create post parameters from factory
  let(:post_attributes) {
    post_attrs = FactoryGirl.attributes_for(:user)
    post_attrs.delete(:authentication_token)
    post_attrs
  }

  ################################
  # LIST
  ################################
  get '/user_accounts' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/user_accounts' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/user_accounts' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:get, 'LIST (as writer)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # CREATE does not make sense for user_accounts -
  # account creation is done by devise/registrations#create
  ################################

  ################################
  # SHOW
  ################################
  get '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { writer_id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/user_name'})
  end

  get '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/user_name'})
  end

  get '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { writer_id }
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/my_account' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'MY ACCOUNT (as reader; own account)', :ok, {expected_json_path: 'data/user_name'})
  end

  get '/my_account' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:get, 'MY ACCOUNT (as reader; invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # UPDATE
  ################################
  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { writer_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as same user - writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as same user - reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { other_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/user_name'})
  end

  ################################
  # UPDATE PREFERENCES
  ################################

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'modify admin preferences', :ok, {expected_json_path: 'data/preferences/volume'})
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'modify reader preferences', :ok, {expected_json_path: 'data/preferences/volume'})
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'modify writer preferences', :ok, {expected_json_path: 'data/preferences/volume'})
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request_options(:put, 'modify preferences as in valid user', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
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

  # Filter (#filter)
  # ================

  post '/user_accounts/filter' do
    let!(:update_site_tz){
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
        response_body_content: ["\"last_seen_at\":null,\"preferences\":null"]
    })
  end

end