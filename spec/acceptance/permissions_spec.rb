# frozen_string_literal: true

require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Permissions' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  let!(:owner_user_2) { FactoryBot.create(:user) }
  let!(:writer_user_2) { FactoryBot.create(:user) }
  let!(:reader_user_2) { FactoryBot.create(:user) }
  let!(:owner_permission_2) { FactoryBot.create(:own_permission, creator: admin_user, user: owner_user_2) }
  let!(:project_2) { owner_permission_2.project }
  let!(:writer_permission_2) { FactoryBot.create(:write_permission, creator: admin_user, user: writer_user_2, project: project_2) }
  let!(:reader_permission_2) { FactoryBot.create(:read_permission, creator: admin_user, user: reader_user_2, project: project_2) }

  # prepare authentication_token for different users
  let(:owner_token_2) { Creation::Common.create_user_token(owner_user_2) }
  let(:writer_token_2) { Creation::Common.create_user_token(writer_user_2) }
  let(:reader_token_2) { Creation::Common.create_user_token(reader_user_2) }

  let(:post_duplicate_attributes) { { project_id: project.id, user_id: writer_user.id, level: 'writer' } }
  let(:post_attributes) { { project_id: project.id, user_id: no_access_user.id, level: 'reader' } }

  ################################
  # LIST - only admin and users with write access to a project
  ################################
  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:expected_unordered_ids) { Permission.where(project_id: project.id).pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, { expected_json_path: 'data/0/level', data_item_count: 3 })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:expected_unordered_ids) { Permission.where(project_id: project.id).pluck(:id) }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'LIST (as owner 1)', :ok, { expected_json_path: 'data/0/level', data_item_count: 3 })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as write 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as read 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST (as no access user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { owner_token_2 }
    standard_request_options(:get, 'LIST (as owner 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { writer_token_2 }
    standard_request_options(:get, 'LIST (as write 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:authentication_token) { reader_token_2 }
    standard_request_options(:get, 'LIST (as read 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  ################################
  # CREATE - only admin and users with write access to a project
  ################################

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, { expected_json_path: 'data/level' })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:post, 'CREATE (as owner 1)', :created, { expected_json_path: 'data/level' })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as write 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as no access token)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { owner_token_2 }
    standard_request_options(:post, 'CREATE (as owner 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { writer_token_2 }
    standard_request_options(:post, 'CREATE (as writer 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/projects/:project_id/permissions' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:raw_post) { { permission: post_attributes }.to_json }
    let(:authentication_token) { reader_token_2 }
    standard_request_options(:post, 'CREATE (as reader 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  ################################
  # Show - only admin and users with write access to a project
  ################################
  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, { expected_json_path: 'data/level' })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'SHOW (as owner 1)', :ok, { expected_json_path: 'data/level' })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as write 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as read 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no acces user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { owner_token_2 }
    standard_request_options(:get, 'SHOW (as owner 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { writer_token_2 }
    standard_request_options(:get, 'SHOW (as write 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { reader_token_2 }
    standard_request_options(:get, 'SHOW (as read 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  ################################
  # Destroy - only admin and users with write access to a project
  ################################

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:delete, 'DESTROY (as owner 1)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as write 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as read 1)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { owner_token_2 }
    standard_request_options(:delete, 'DESTROY (as owner 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { writer_token_2 }
    standard_request_options(:delete, 'DESTROY (as write 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/projects/:project_id/permissions/:id' do
    parameter :project_id, 'Requested project id (in path/route)', required: true
    parameter :id, 'Requested permission id (in path/route)', required: true
    let(:project_id) { project.id }
    let(:id) { writer_permission.id }
    let(:authentication_token) { reader_token_2 }
    standard_request_options(:delete, 'DESTROY (as read 2)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end
end
