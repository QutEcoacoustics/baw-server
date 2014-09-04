require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Permissions' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    @admin_user = FactoryGirl.create(:admin)
    @other_user = FactoryGirl.create(:user)
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)

    @user_write_1 = FactoryGirl.create(:user)
    @user_read_1 = FactoryGirl.create(:user)
    @user_write_2 = FactoryGirl.create(:user)
    @user_read_2 = FactoryGirl.create(:user)

    @permission_write_1 = FactoryGirl.create(:write_permission, creator: @admin_user, user: @user_write_1)
    @project_1 = @permission_write_1.project

    @permission_read_1 = FactoryGirl.create(:read_permission, creator: @admin_user, user: @user_read_1, project: @project_1)

    @permission_write_2 = FactoryGirl.create(:write_permission, creator: @admin_user, user: @user_write_2)
    @project_2 = @permission_write_2.project

    @permission_read_2 = FactoryGirl.create(:read_permission, creator: @admin_user, user: @user_read_2, project: @project_2)
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:user_write_1_token) { "Token token=\"#{@user_write_1.authentication_token}\"" }
  let(:user_read_1_token) { "Token token=\"#{@user_read_1.authentication_token}\"" }
  let(:user_write_2_token) { "Token token=\"#{@user_write_2.authentication_token}\"" }
  let(:user_read_2_token) { "Token token=\"#{@user_read_2.authentication_token}\"" }

  let(:post_duplicate_attributes) { {project_id: @project_1.id, user_id: @user_write_1.id, level: 'writer'} }
  let(:post_attributes) { {project_id: @project_1.id, user_id: @other_user.id, level: 'reader'} }

  ################################
  # LIST - only admin and users with write access to a project
  ################################
  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(project_id: @project_1.id).pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options('LIST (as admin)', :ok, {expected_json_path: 'data/0/level', data_item_count: 2})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(project_id: @project_1.id).pluck(:id) }
    let(:authentication_token) { user_write_1_token }
    standard_request_options('LIST (as write 1)', :ok, {expected_json_path: 'data/0/level', data_item_count: 2})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_read_1.id).pluck(:id) }
    let(:authentication_token) { user_read_1_token }
    standard_request_options('LIST (as read 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_write_2.id).pluck(:id) }
    let(:authentication_token) { user_write_2_token }
    standard_request_options('LIST (as write 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_read_2.id).pluck(:id) }
    let(:authentication_token) { user_read_2_token }
    standard_request_options('LIST (as read 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @other_user.id).pluck(:id) }
    let(:authentication_token) { other_user_token }
    standard_request_options('LIST (as other token)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @unconfirmed_user.id).pluck(:id) }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('LIST (as unconfirmed_token)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { [] }
    let(:authentication_token) { invalid_token }
    standard_request_options('CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # CREATE - only admin and users with write access to a project
  ################################
  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options('CREATE (as admin)', :created, {expected_json_path: 'data/level'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { user_write_1_token }
    standard_request_options('CREATE (as write 1)', :created, {expected_json_path: 'data/level'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { user_read_1_token }
    standard_request_options('CREATE (as read 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { user_write_2_token }
    standard_request_options('CREATE (as write 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { user_read_2_token }
    standard_request_options('CREATE (as read 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options('CREATE (as other token)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {permission: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options('CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Show - only admin and users with write access to a project
  ################################
  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { admin_token }
    standard_request_options('SHOW (as admin)', :ok, {expected_json_path: 'data/level'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_write_1_token }
    standard_request_options('SHOW (as write 1)', :ok, {expected_json_path: 'data/level'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_read_1_token }
    standard_request_options('SHOW (as read 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_write_2_token }
    standard_request_options('SHOW (as write 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_read_2_token }
    standard_request_options('SHOW (as read 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { other_user_token }
    standard_request_options('SHOW (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('SHOW (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { invalid_token }
    standard_request_options('UPDATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Destroy - only admin and users with write access to a project
  ################################
  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { admin_token }
    standard_request_options('DESTROY (as admin)', :no_content)
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_write_1_token }
    standard_request_options('DESTROY (as write 1)', :no_content)
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_read_1_token }
    standard_request_options('DESTROY (as read 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_write_2_token }
    standard_request_options('DESTROY (as write 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { user_read_2_token }
    standard_request_options('DESTROY (as read 2)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { other_user_token }
    standard_request_options('DESTROY (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('DESTROY (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { invalid_token }
    standard_request_options('DESTROY (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

end