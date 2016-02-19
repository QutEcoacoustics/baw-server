require 'rails_helper'
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

  create_entire_hierarchy

  let!(:comment_other) {
    FactoryGirl.create(
        :comment,
        comment: 'the other comment text',
        creator: other_user,
        audio_event: audio_event) }
  let!(:comment_reader) {
    FactoryGirl.create(
        :comment,
        comment: 'the reader comment text',
        creator: reader_user,
        audio_event: audio_event) }
  let!(:comment_writer) {
    FactoryGirl.create(
        :comment,
        id: 99876,
        comment: 'the writer comment text',
        creator: writer_user,
        audio_event: audio_event)
  }

  let(:post_attributes) { {comment: 'new comment content'} }
  let(:post_attributes_flag_report) { {flag: 'report'} }
  let(:post_attributes_flag_nil) { {flag: nil} }

  ################################
  # LIST
  ################################
  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 4})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 4})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, {expected_json_path: 'data/0/comment', data_item_count: 4})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'LIST (as other)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'LIST (as other token, reader comment)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed_token)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # CREATE
  ################################
  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/comment'})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_token }
    standard_request_options(:post, 'CREATE (as other token)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # Show
  ################################
  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/comment'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: ['data/created_at', 'data/comment']})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: ['data/updated_at', 'data/comment']})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/comment'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:authentication_token) { other_token }
    standard_request_options(:get, 'SHOW (as other user showing writer comment)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_other.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer showing other comment)', :ok, {expected_json_path: 'data/comment'})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  ################################
  # Update
  ################################
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, {expected_json_path: 'data/comment'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :ok, {expected_json_path: 'data/comment'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  # user can only update their own comments
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { other_token }
    standard_request_options(:put, 'UPDATE (as other updating comment created by writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes_flag_report}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer updating flag to report for comment created by writer)', :ok, {expected_json_path: 'data/flag', response_body_content: 'report'})
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { {audio_event_comment: post_attributes_flag_nil}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer updating flag to nil for comment created by writer)', :ok, {expected_json_path: 'data/flag', response_body_content: '"flag":null'})
  end

  ################################
  # Destroy
  ################################
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DESTROY (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DESTROY (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (as invalid user)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  # users can only delete their own comments
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DESTROY (as other deleting comment created by writer)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  #####################
  # Filter
  #####################

  post '/audio_event_comments/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'comment' => {
                'contains' => 'comment'
            }
        },
        'projection' => {
            'include' => ['id', 'audio_event_id', 'comment']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
        expected_json_path: 'meta/filter/comment',
        data_item_count: 4,
        regex_match: /"comment"\:"the writer comment text"/,
        response_body_content: "\"comment\":\"comment text",
        invalid_content: "\"project_ids\":[{\"id\":"
    })
  end

end