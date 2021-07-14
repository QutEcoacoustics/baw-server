# frozen_string_literal: true


require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def audio_recording_params
  parameter :audio_recording_id, 'Accessed audio recording ID (in path/route)', required: true
  parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true
end

def user_params
  parameter :user_id, 'Get taggings for user id (in path/route)', required: true
end

def body_params
  parameter :project_id, 'Accessed project ID (in path/route)', required: true
  parameter :site_id, 'Accessed site ID (in path/route)', required: true
  parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
  parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
  parameter :id, 'Requested tag ID (in path/route)', required: true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Taggings' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  # prepare ids needed for paths in requests below
  let!(:existing_tag) { FactoryBot.create(:tag, text: 'existing') }

  # prepare ids needed for paths in requests below
  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:audio_recording_id) { audio_recording.id }
  let(:audio_event_id) { audio_event.id }
  let(:id) { tagging.id }
  let(:user_id) { tagging.creator_id }

  # Create post parameters from factory
  let(:post_attributes) { { tag_id: existing_tag.id } }
  let(:post_nested_attributes) { { 'tag_attributes' => FactoryBot.attributes_for(:tag) } }
  let(:post_invalid_nested_attributes) { { 'tag_attributes' => FactoryBot.attributes_for(:tag, type_of_tag: 'invalid value') } }

  ################################
  # LIST
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    audio_recording_params
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer, with shallow path)', :ok, { expected_json_path: 'data/0/tag_id', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    audio_recording_params
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader, with shallow path)', :ok, { expected_json_path: 'data/0/tag_id', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    audio_recording_params
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST (as no access user, with shallow path)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/user_accounts/:user_id/taggings' do
    user_params
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader, user taggings)', :ok, { expected_json_path: 'data/0/tag_id', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    audio_recording_params
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (with invalid token, with shallow path)', :unauthorized, { expected_json_path: get_json_error_path(:sign_in) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    audio_recording_params
    standard_request_options(:get, 'LIST (as anonymous user, with shallow path)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # SHOW
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    body_params
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer, with shallow path)', :ok, { expected_json_path: 'data/tag_id' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    body_params
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader, with shallow path)', :ok, { expected_json_path: 'data/tag_id' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    body_params
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user, with shallow path)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    body_params
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (with invalid token, with shallow path)', :unauthorized, { expected_json_path: get_json_error_path(:sign_in) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    body_params
    standard_request_options(:get, 'SHOW (as anonymous user, with shallow path)', :unauthorized, { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # CREATE
  ################################

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { { 'tagging' => post_attributes }.to_json }

    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (with tag_id as writer, with shallow path)', :created, { expected_json_path: 'data/tag_id' })
  end

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { { 'tagging' => post_nested_attributes }.to_json }

    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (with tag_attributes as writer, with shallow path)', :created, { expected_json_path: 'data/tag_id' })
  end

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { { 'tagging' => post_invalid_nested_attributes }.to_json }

    let(:authentication_token) { writer_token }
    # 0 - index in array
    standard_request_options(:post, 'CREATE (invalid tag_attributes as writer, with shallow path)', :unprocessable_entity,
                             { expected_json_path: 'type_of_tag', response_body_content: '"is not included in the list"' })
  end

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { { tagging: { tag_attributes: { is_taxonomic: false, text: existing_tag.text, type_of_tag: 'looks like', retired: false } } }.to_json }

    let(:authentication_token) { writer_token }

    #example 'CREATE (existing tag name as writer) - 200', :document => true do
    #  # create orphaned tags
    #  2.times do |i|
    #    FactoryBot.create(:tag)
    #  end
    #
    #  do_request
    #  status.should == 200
    #  response_body.should have_json_path('2/is_taxonomic')
    #end
    standard_request_options(:post, 'CREATE (with tag_attributes but existing tag text as writer, with shallow path)', :created,
                             { expected_json_path: 'data/tag_id' })
  end

  #####################
  # Filter
  #####################

  post '/taggings/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'audio_event_id' => {
            'gt' => 0
          }
        },
        'projection' => {
          'include' => ['id', 'audio_event_id', 'tag_id', 'created_at']
        }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as reader, with projection)', :ok,
                             {
                               expected_json_path: 'data/0/audio_event_id',
                               data_item_count: 1,
                               response_body_content: '"filter":{"audio_event_id":{"gt":0}},"sorting":{"order_by":"id","direction":"asc"},"paging":{"page":1,"items":25,"total":1,"max_page":1,"current":"http://localhost:3000/taggings/filter?direction=asc\u0026items=25\u0026order_by=id\u0026page=1"'
                             })
  end

  post '/taggings/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'audio_events.is_reference' => {
            'eq' => false
          }
        },
        'projection' => {
          'include' => ['id', 'audio_event_id', 'tag_id', 'created_at']
        }
      }.to_json
    }
    standard_request_options(:post, 'FILTER (as reader, with projection for associated table)', :ok,
                             {
                               expected_json_path: 'data/0/audio_event_id',
                               data_item_count: 1,
                               response_body_content: '"filter":{"audio_events.is_reference":{"eq":false}},"sorting":{"order_by":"id","direction":"asc"},"paging":{"page":1,"items":25,"total":1,"max_page":1,"current":"http://localhost:3000/taggings/filter?direction=asc\u0026items=25\u0026order_by=id\u0026page=1"'
                             })
  end
end
