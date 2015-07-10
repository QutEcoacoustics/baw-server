require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'SavedSearches' do

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
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:user_token) { "Token token=\"#{@user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:post_attributes) { {name: 'saved search name'} }

  ################################
  # LIST
  ################################
  get '/saved_searches' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 1})
  end

  get '/saved_searches' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 3})
  end

  get '/saved_searches' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 5})
  end

  get '/saved_searches' do
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'LIST (as user token)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 3})
  end

  get '/saved_searches' do
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'LIST (as other token, other user comment)', :ok, {expected_json_path: 'data/0/stored_query', data_item_count: 2})
  end

  get '/saved_searches' do
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'LIST (as other token, user comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/saved_searches' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed_token)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/saved_searches' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # CREATE
  ################################
  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:post, 'CREATE (as user token)', :created, {expected_json_path: 'data/stored_query'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { other_user_token }
    standard_request_options(:post, 'CREATE (as other token)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/saved_searches' do
    let(:raw_post) { {saved_search: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  ################################
  # Show
  ################################
  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_user.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/stored_query'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_user.audio_event_id }
    let(:id) { @comment_user.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: ['data/created_at', 'data/stored_query']})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_user.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: ['data/updated_at', 'data/stored_query']})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_user.id }
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'SHOW (as user)', :ok, {expected_json_path: 'data/stored_query'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_user.id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'SHOW (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_writer.id }
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'SHOW (as other user showing writer comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @other_comment.id }
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'SHOW (as user showing other comment)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
    let(:id) { @comment_user.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/saved_searches/:id' do
    parameter :id, 'Requested saved search id (in path/route)', required: true
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

  post '/saved_searches/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'stored_query' => {
                'contains' => 'comment'
            }
        },
        'projection' => {
            'include' => ['id', 'name', 'stored_query']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
                                      expected_json_path: 'meta/filter/stored_query',
                                      data_item_count: 3,
                                      regex_match: /"stored_query"\:"the writer stored query"/,
                                      response_body_content: "\"stored_query\":\"comment text"
                                  })
  end

end