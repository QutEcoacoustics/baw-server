require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Users' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  # prepare ids needed for paths in requests below
  let(:writer_id) { @write_permission.user.id }
  let(:reader_id) { @read_permission.user.id }
  let(:other_id) { @other_user.user.id }
  let(:admin_id) { @admin_user.id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) {
    post_attrs = FactoryGirl.attributes_for(:user)
    post_attrs.delete(:authentication_token)
    post_attrs
  }

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
    @other_user = FactoryGirl.create(:write_permission)
    @admin_user = FactoryGirl.create(:admin)
  end

=begin
                                        user_accounts GET    /user_accounts(.:format)                                                                                                           user_accounts#index
                                                      POST   /user_accounts(.:format)                                                                                                           user_accounts#create
                                     new_user_account GET    /user_accounts/new(.:format)                                                                                                       user_accounts#new
                                    edit_user_account GET    /user_accounts/:id/edit(.:format)                                                                                                  user_accounts#edit
                                         user_account GET    /user_accounts/:id(.:format)                                                                                                       user_accounts#show
                                                      PUT    /user_accounts/:id(.:format)                                                                                                       user_accounts#update
                                                      DELETE /user_accounts/:id(.:format)                                                                                                       user_accounts#destroy
                                           my_account GET    /my_account(.:format)                                                                                                              user_accounts#my_account
                                     my_account_prefs PUT    /my_account/prefs(.:format)                                                                                                        user_accounts#modify_preferences
=end

  ################################
  # LIST
  ################################
  get '/user_accounts' do
    let(:authentication_token) { writer_token }
    standard_request('LIST (as writer)', 403, nil, true)
  end

  get '/user_accounts' do
    let(:authentication_token) { reader_token }
    standard_request('LIST (as reader)', 403, nil, true)
  end

  get '/user_accounts' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('LIST (with invalid token)', 401, nil, true)
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
    standard_request('SHOW (as writer)', 200, 'user_name', true)
  end

  get '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:authentication_token) { reader_token }
    standard_request('SHOW (as reader)', 200, 'user_name', true)
  end

  get '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { writer_id }
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('SHOW (with invalid token)', 401, nil, true)
  end

  get '/my_account' do
    let(:authentication_token) { reader_token }
    standard_request('MY ACCOUNT (as reader; own account)', 200, 'user_name', true)
  end

  get '/my_account' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('MY ACCOUNT (as reader; invalid token)', 401, nil, true)
  end

  ################################
  # UPDATE
  ################################
  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { writer_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request('UPDATE (as same user - writer)', 204, nil, true)
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request('UPDATE (as same user - reader)', 204, nil, true)
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { other_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request('UPDATE (as other user)', 403, nil, true)
  end

  put '/user_accounts/:id' do
    parameter :id, 'Requested user ID (in path/route)', required: true
    let(:id) { reader_id }
    let(:raw_post) { {user: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request('UPDATE (as admin)', 204, nil, true)
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { admin_token }
    standard_request('modify admin preferences', 204, nil, true)
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { reader_token }
    standard_request('modify reader preferences', 204, nil, true)
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { writer_token }
    standard_request('modify writer preferences', 204, nil, true)
  end

  put '/my_account/prefs' do
    let(:raw_post) { '{"volume":1,"muted":false}' }
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('modify preferences as in valid user', 401, nil, true)
  end

end