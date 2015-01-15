require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'AudioEventComments' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    @user = FactoryGirl.create(:user)
    @admin_user = FactoryGirl.create(:admin)
    @other_user = FactoryGirl.create(:user)
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)

    @write_permission = FactoryGirl.create(:write_permission, creator: @user)
    @writer_user = @write_permission.user

    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project, creator: @user)
    @reader_user = @read_permission.user
    @user_permission = FactoryGirl.create(:read_permission, creator: @user, project: @write_permission.project, user: @user)

    @other_permission = FactoryGirl.create(:write_permission, creator: @admin_user, user: @other_user)

    @other_comment = FactoryGirl.create(
        :comment,
        comment: 'the other comment text',
        creator: @other_user,
        audio_event: @other_permission.project.sites.order(:id).first
                         .audio_recordings.order(:id).first
                         .audio_events.order(:id).first)

    @comment_user = FactoryGirl.create(
        :comment,
        comment: 'the user comment text',
        creator: @user,
        audio_event: @user_permission.project.sites.order(:id).first
                         .audio_recordings.order(:id).first
                         .audio_events.order(:id).first)

    @comment_writer = FactoryGirl.create(
        :comment,
        id: 99876,
        comment: 'the writer comment text',
        creator: @writer_user,
        audio_event: @write_permission.project.sites.order(:id).first
                         .audio_recordings.order(:id).first
                         .audio_events.order(:id).first)
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:user_token) { "Token token=\"#{@user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:post_attributes) { {comment: 'new comment content'} }
  let(:post_attributes_flag_report) { {flag: 'report'} }
  let(:post_attributes_flag_nil) { {flag: nil} }

  ################################
  # LIST
  ################################
  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: @comment_user.audio_event_id).pluck(:id) }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 3})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: @comment_user.audio_event_id).pluck(:id) }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 3})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:expected_unordered_ids) { AudioEventComment.pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 5})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: @comment_user.audio_event_id).pluck(:id) }
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'LIST (as user token)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 3})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @other_comment.audio_event_id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: @other_comment.audio_event_id).pluck(:id) }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'LIST (as other token, other user comment)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 2})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'LIST (as other token, user comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed_token)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # CREATE
  ################################
  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:post, 'CREATE (as user token)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options(:post, 'CREATE (as other token)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Show
  ################################
  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/comment'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: ['data/created_at', 'data/comment']})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: ['data/updated_at', 'data/comment']})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'SHOW (as user)', :ok, {expected_json_path: 'data/comment'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'SHOW (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'SHOW (as other user showing writer comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @other_comment.audio_event_id }
    let(:id) { @other_comment.id }
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'SHOW (as user showing other comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Update
  ################################
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/comment'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:put, 'UPDATE (as user)', :ok, {expected_json_path: 'data/comment'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # user can only update their own comments
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:put, 'UPDATE (as user updating comment created by writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes_flag_report}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:put, 'UPDATE (as user updating flag to report for comment created by writer)', :ok, {expected_json_path: 'data/flag', response_body_content: 'report'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes_flag_nil}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:put, 'UPDATE (as user updating flag to nil for comment created by writer)', :ok, {expected_json_path: 'data/flag', response_body_content: '"flag":null'})
  end

  ################################
  # Destroy
  ################################
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as user)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:delete, 'DESTROY (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DESTROY (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # users can only delete their own comments
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_writer.audio_event_id }
    let(:id) { @comment_writer.id }
    let(:authentication_token) { user_token }
    standard_request_options(:delete, 'DESTROY (as user deleting comment created by writer)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  #####################
  # Filter
  #####################

  post '/audio_events/:audio_event_id/comments/filter' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'comment' => {
                'contains' => 'comment text'
            }
        },
        'projection' => {
            'include' => ['id', 'audio_event_id', 'comment']}
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok)
  end

end