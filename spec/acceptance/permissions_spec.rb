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

  let(:post_attributes) { {project_id: @project_1.id, user_id: @user_write_1.id, level: 'writer'} }

  ################################
  # LIST
  ################################
  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @admin_user.id).pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options('LIST (as admin)', :ok, {expected_json_path: 'data/0/level', data_item_count: 3})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_write_1.id).pluck(:id) }
    let(:authentication_token) { user_write_1_token }
    standard_request_options('LIST (as write 1, project 1)', :ok, {expected_json_path: 'data/0/level', data_item_count: 3})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_read_1.id).pluck(:id) }
    let(:authentication_token) { user_read_1_token }
    standard_request_options('LIST (as read 1, project 1)', :ok, {expected_json_path: 'data/0/level', data_item_count: 5})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_write_2.id).pluck(:id) }
    let(:authentication_token) { user_write_2_token }
    standard_request_options('LIST (as write 2, project 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:expected_unordered_ids) { Permission.where(user_id: @user_read_2.id).pluck(:id) }
    let(:authentication_token) { user_read_2_token }
    standard_request_options('LIST (as read 2, project 1)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
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
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('LIST (as unconfirmed_token)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:authentication_token) { invalid_token }
    standard_request_options('CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # CREATE
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
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options('CREATE (as reader)', :created, {expected_json_path: 'data/level'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options('CREATE (as admin)', :created, {expected_json_path: 'data/level'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options('CREATE (as user token)', :created, {expected_json_path: 'data/level'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options('CREATE (as other token)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options('CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Show
  ################################
  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { writer_token }
    standard_request_options('SHOW (as writer)', :ok, {expected_json_path: 'data/level'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { reader_token }
    standard_request_options('SHOW (as reader)', :ok, {expected_json_path: 'data/level'})
  end

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
    let(:authentication_token) { user_token }
    standard_request_options('SHOW (as user)', :ok, {expected_json_path: 'data/level'})
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
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:authentication_token) { other_user_token }
    standard_request_options('SHOW (as other user showing writer comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:audio_event_id) { @other_comment.audio_event_id }
    let(:id) { @other_comment.id }
    let(:authentication_token) { user_token }
    standard_request_options('SHOW (as user showing other comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
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
  # Update
  ################################
  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options('UPDATE (as writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options('UPDATE (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options('UPDATE (as admin)', :ok, {expected_json_path: 'data/level'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options('UPDATE (as user)', :ok, {expected_json_path: 'data/level'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options('UPDATE (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options('UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options('UPDATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # user can only update their own comments
  put '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options('UPDATE (as user updating comment created by writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  ################################
  # Destroy
  ################################
  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { writer_token }
    standard_request_options('DESTROY (as writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { @project_1.id }
    let(:id) { @permission_write_1.id }
    let(:authentication_token) { reader_token }
    standard_request_options('DESTROY (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

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
    let(:authentication_token) { admin_token }
    standard_request_options('DESTROY (as user)', :no_content)
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

  # users can only delete their own comments
  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:authentication_token) { user_token }
    standard_request_options('DESTROY (as user deleting comment created by writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

end