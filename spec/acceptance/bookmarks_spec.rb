# frozen_string_literal: true

require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def bookmarks_id_param
  parameter :id, 'Bookmark id in request url', required: true
end

def bookmarks_body_params
  parameter :audio_recording_id, 'Bookmark audio recording id in request body', required: true

  parameter :name, 'Bookmark name in request body', required: false
  parameter :offset_seconds, 'Bookmark offset seconds in request body', required: false
  parameter :category, 'Bookmark category in request body', required: false
  parameter :description, 'Bookmark description in request body', required: false
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Bookmarks' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  let(:body_attributes) { FactoryBot.attributes_for(:bookmark, audio_recording_id: bookmark.audio_recording_id).to_json }

  # List (#index)
  # ============

  # list all bookmarks
  # ------------------

  get '/bookmarks' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'LIST (as owner)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, { expected_json_path: 'data/0/category', data_item_count: 1 })
  end

  get '/bookmarks' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST (as other user)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (with invaild token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  # List bookmarks filtered by name
  # -------------------------------

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, name: 'the_expected_name', creator: reader_user)
      FactoryBot.create(:bookmark, name: 'the_unexpected_name', creator: reader_user)
    }

    standard_request_options(:get, 'LIST matching name (as reader)', :ok, {
                               expected_json_path: 'data/0/offset_seconds',
                               response_body_content: 'the_expected_name',
                               invalid_content: 'the_unexpected_name',
                               data_item_count: 1
                             })
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { writer_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, name: 'the_expected_name', creator: writer_user)
      FactoryBot.create(:bookmark, name: 'the_unexpected_name', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching name (as writer)', :ok, {
                               expected_json_path: 'data/0/offset_seconds',
                               response_body_content: 'the_expected_name',
                               invalid_content: 'the_unexpected_name',
                               data_item_count: 1
                             })
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { no_access_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, name: 'the_expected_name', creator: writer_user)
      FactoryBot.create(:bookmark, name: 'the_unexpected_name', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching name (as no access user)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, name: 'the_expected_name', creator: writer_user)
      FactoryBot.create(:bookmark, name: 'the_unexpected_name', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching name (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  # List bookmarks filtered by category
  # -----------------------------------

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, category: 'the_expected_category', creator: reader_user)
      FactoryBot.create(:bookmark, category: 'the_unexpected_category', creator: reader_user)
    }

    standard_request_options(:get, 'LIST matching category (as reader)', :ok, {
                               expected_json_path: 'data/0/offset_seconds',
                               response_body_content: 'the_expected_category',
                               invalid_content: 'the_unexpected_category',
                               data_item_count: 1
                             })
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { writer_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, category: 'the_expected_category', creator: writer_user)
      FactoryBot.create(:bookmark, category: 'the_unexpected_category', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching category (as writer)', :ok, {
                               expected_json_path: 'data/0/offset_seconds',
                               response_body_content: 'the_expected_category',
                               invalid_content: 'the_unexpected_category',
                               data_item_count: 1
                             })
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { no_access_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, category: 'the_expected_category', creator: writer_user)
      FactoryBot.create(:bookmark, category: 'the_unexpected_category', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching category (as no access user)', :ok, { response_body_content: '200', data_item_count: 0 })
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryBot.create(:bookmark, category: 'the_expected_category', creator: writer_user)
      FactoryBot.create(:bookmark, category: 'the_unexpected_category', creator: writer_user)
    }

    standard_request_options(:get, 'LIST matching category (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  # Create (#create)
  # ================

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, { expected_json_path: 'data/offset_seconds' })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { owner_token }
    standard_request_options(:post, 'CREATE (as owner)', :created, { expected_json_path: 'data/offset_seconds' })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, { expected_json_path: 'data/offset_seconds' })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, { expected_json_path: 'data/offset_seconds' })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as other user)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  post '/bookmarks' do
    bookmarks_body_params
    let(:raw_post) { body_attributes }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  # New Item (#new)
  # ===============

  get '/bookmarks/new' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW (as admin)', :ok, { expected_json_path: 'data/offset_seconds' })
  end

  get '/bookmarks/new' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'NEW (as owner)', :ok, { expected_json_path: 'data/offset_seconds' })
  end

  get '/bookmarks/new' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW (as writer)', :ok, { expected_json_path: 'data/offset_seconds' })
  end

  get '/bookmarks/new' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW (as reader)', :ok, { expected_json_path: 'data/offset_seconds' })
  end

  get '/bookmarks/new' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'NEW (as no access user)', :ok, { expected_json_path: 'data/offset_seconds' })
  end

  get '/bookmarks/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (as anonymous user)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  # Existing Item (#show)
  # ================

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { bookmark.id }
    standard_request_options(:get, 'SHOW (as reader)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    let(:id) { bookmark.id }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {
                               expected_json_path: 'data/offset_seconds',
                               response_body_content: '"offset_seconds":4.0'
                             })
  end

  # Update (#update)
  # ================

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { bookmark.id }
    let(:raw_post) { body_attributes }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    let(:id) { bookmark.id }
    let(:raw_post) { body_attributes }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, { expected_json_path: 'data/category' })
  end

  # Delete (#destroy)
  # ================

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { bookmark.id }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    let(:id) { bookmark.id }
    standard_request_options(:delete, 'DESTROY (as writer)', :no_content, { expected_response_has_content: false, expected_response_content_type: nil })
  end

  # Filter (#filter)
  # ================

  post '/bookmarks/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'and' => {
            'offset_seconds' => {
              'less_than' => 123_456
            },
            'description' => {
              'contains' => 'description'
            }
          }
        },
        'projection' => {
          'include' => ['category']
        }
      }.to_json
    }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'FILTER (as writer)', :ok, { expected_json_path: 'data/0/category', data_item_count: 1 })
  end
end
