# frozen_string_literal: true


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

  # TODO: sort out what these tests should actually test
  # TODO: don't forget about reference audio events

  let(:audio_event_reference) {
    FactoryBot.create(
      :audio_event,
      id: 99_998,
      creator: writer_user,
      audio_recording: audio_recording,
      is_reference: true
    )
  }
  let!(:comment_other) {
    FactoryBot.create(
      :comment,
      id: 99_874,
      comment: 'the no access comment text',
      creator: no_access_user,
      audio_event: audio_event_reference
    ) # different audio_event
  }
  let!(:comment_reader) {
    FactoryBot.create(
      :comment,
      id: 99_875,
      comment: 'the reader comment text',
      creator: reader_user,
      audio_event: audio_event
    )
  }
  let!(:comment_writer) {
    AudioEventComment.where(creator: writer_user, audio_event: audio_event).first
  }
  let!(:comment_owner) {
    FactoryBot.create(
      :comment,
      id: 99_877,
      comment: 'the owner comment text',
      creator: owner_user,
      audio_event: audio_event
    )
  }

  let(:post_attributes) { { comment: 'new comment content' } }
  let(:post_attributes_flag_report) { { flag: 'report' } }
  let(:post_attributes_flag_nil) { { flag: nil } }

  ################################
  # LIST
  ################################

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, { expected_json_path: 'data/0/comment', data_item_count: 3 })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'LIST (as owner)', :ok, { expected_json_path: 'data/0/comment', data_item_count: 3 })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, { expected_json_path: 'data/0/comment', data_item_count: 3 })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, { expected_json_path: 'data/0/comment', data_item_count: 3 })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:expected_unordered_ids) { AudioEventComment.where(audio_event_id: audio_event.id).pluck(:id) }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST (as other)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST (as other token, reader comment)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    standard_request_options(:get, 'LIST (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # CREATE
  ################################
  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, { expected_json_path: 'data/comment' })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:post, 'CREATE (as owner)', :created, { expected_json_path: 'data/comment' })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, { expected_json_path: 'data/comment' })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, { expected_json_path: 'data/comment' })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as other token)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # Show
  ################################
  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, { expected_json_path: ['data/updated_at', 'data/comment'] })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'SHOW (as owner)', :ok, { expected_json_path: 'data/comment' })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, { expected_json_path: 'data/comment' })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, { expected_json_path: ['data/created_at', 'data/comment'] })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, { expected_json_path: 'data/comment' })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as other user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as other user showing writer comment)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_other.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer showing other comment)', :ok, { expected_json_path: 'data/comment' })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  get '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    standard_request_options(:get, 'SHOW (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # Update
  ################################
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, { expected_json_path: 'data/comment' })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:put, 'UPDATE (as owner)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_owner.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:put, 'UPDATE (as owner updating own comment)', :ok, { expected_json_path: 'data/comment' })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :ok, { expected_json_path: 'data/comment' })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as other user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (as invalid user)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_owner.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user, owner comment)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user, writer comment)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user, reader comment)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_other.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user, other comment)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  # user can only update their own comments
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { { audio_event_comment: post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:put, 'UPDATE (as other updating comment created by writer)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { { audio_event_comment: post_attributes_flag_report }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer updating flag to report for comment created by writer)', :ok, { expected_json_path: 'data/flag', response_body_content: 'report' })
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:raw_post) { { audio_event_comment: post_attributes_flag_nil }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer updating flag to nil for comment created by writer)', :ok, { expected_json_path: 'data/flag', response_body_content: '"flag":null' })
  end

  ################################
  # Destroy
  ################################
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DESTROY (as admin)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:delete, 'DESTROY (as owner)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_owner.id }
    let(:authentication_token) { owner_token }
    standard_request_options(:delete, 'DESTROY (as owner destroying own comment)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DESTROY (as writer)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DESTROY (as reader)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as no access user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DESTROY (invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_reader.id }
    standard_request_options(:delete, 'DESTROY (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  # users can only delete their own comments
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { audio_event.id }
    let(:id) { comment_writer.id }
    let(:authentication_token) { no_access_token }
    standard_request_options(:delete, 'DESTROY (as other deleting comment created by writer)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  #####################
  # Filter
  #####################

  post '/audio_event_comments/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'comment' => {
            'contains' => 'comment'
          }
        },
        'projection' => {
          'include' => ['id', 'audio_event_id', 'comment']
        }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {
                               expected_json_path: 'meta/filter/comment',
                               data_item_count: 4,
                               response_body_content: ['"the owner comment text"', '"the reader comment text"', '"the no access comment text"', '"comment":"comment text '],
                               invalid_content: '"project_ids":[{"id":'
                             })
  end

  post '/audio_event_comments/filter' do
    # anonymous users cannot access any audio event comments,
    # even if the audio event is a reference.
    let(:raw_post) {
      {
        'filter' => {
          'comment' => {
            'contains' => 'comment'
          }
        },
        'projection' => {
          'include' => ['id', 'audio_event_id', 'comment']
        }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end
end
