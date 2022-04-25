# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def get_index_params
  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
  parameter :start_offset, 'Request audio events within offset bounds (start)'
  parameter :end_offset, 'Request audio events within offset bounds (end)'
end

def get_route_params
  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
  parameter :id, 'Requested audio event id (in path/route)', required: true
end

def get_modify_params
  parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event,
    required: true
  parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
  parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event,
    required: true
  parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
  parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event
end

# https://github.com/zipmark/rspec_api_documentation
resource 'AudioEvents' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  let!(:existing_tag) { FactoryBot.create(:tag, text: 'existing') }

  let(:audio_recording_id) { audio_recording.id }
  let(:id) { audio_event.id }

  # Create post parameters from factory
  let(:post_attributes) { FactoryBot.attributes_for(:audio_event) }
  let(:post_nested_attributes) {
    { tags_attributes: [
      FactoryBot.attributes_for(:tag),
      {
        is_taxonomic: existing_tag.is_taxonomic,
        text: existing_tag.text,
        type_of_tag: existing_tag.type_of_tag,
        retired: existing_tag.retired
      }
    ] }
  }

  ################################
  # LIST
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'LIST (as admin)', :ok,
      { expected_json_path: 'data/0/start_time_seconds', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'LIST (as owner)', :ok,
      { expected_json_path: 'data/0/start_time_seconds', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'LIST (as writer)', :ok,
      { expected_json_path: 'data/0/start_time_seconds', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader)', :ok,
      { expected_json_path: 'data/0/start_time_seconds', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader with shallow path)', :ok,
      { expected_json_path: 'data/0/start_time_seconds', data_item_count: 1 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader with shallow path testing quoted numbers)', :ok,
      {
        data_item_count: 1,
        expected_json_path: 'data/0/start_time_seconds',
        response_body_content: ['"start_time_seconds":5.2,',
                                '"end_time_seconds":5.8,',
                                '"low_frequency_hertz":400.0,',
                                '"high_frequency_hertz":6000.0']
      })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'LIST (as no access user)', :ok,
      { response_body_content: '200', data_item_count: 0 })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'LIST (with invalid token)', :unauthorized,
      { expected_json_path: get_json_error_path(:sign_in) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    get_index_params
    standard_request_options(:get, 'LIST (as anonymous user)', :ok,
      { remove_auth: true, response_body_content: '200', data_item_count: 0 })
  end

  ################################
  # SHOW
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { admin_token }

    standard_request_options(:get, 'SHOW (as admin)', :ok, { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'SHOW (as owner)', :ok, { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (as writer)', :ok, { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader)', :ok, { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader with shallow path)', :ok,
      { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { reader_token }
    let(:id) { @audio_event.id }
    let(:audio_recording_id) { @other_audio_recording_id }

    before do
      @other_audio_recording_id = project.sites[0].audio_recordings[0].id
      @audio_event = FactoryBot.create(:audio_event, audio_recording_id: @other_audio_recording_id,
        start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
    end

    standard_request_options(:get, 'SHOW (as reader with shallow path for reference audio event with no access to audio recording)',
      :ok, { expected_json_path: 'data/start_time_seconds' })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader with shallow path testing quoted numbers)', :ok,
      {
        expected_json_path: 'data/start_time_seconds',
        response_body_content: ['"start_time_seconds":5.2,',
                                '"end_time_seconds":5.8,',
                                '"high_frequency_hertz":6000.0,',
                                '"low_frequency_hertz":400.0']
      })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'SHOW (as no access user)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { invalid_token }

    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized,
      { expected_json_path: get_json_error_path(:sign_in) })
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    standard_request_options(:get, 'SHOW (as anonymous user', :unauthorized,
      { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # CREATE
  ################################
  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { admin_token }

    standard_request_options(:post, 'CREATE (as admin)', :created, { expected_json_path: 'data/is_reference' })
  end

  post 'audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { owner_token }

    standard_request_options(:post, 'CREATE (as owner)', :created, { expected_json_path: 'data/is_reference' })
  end

  post 'audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { writer_token }

    standard_request_options(:post, 'CREATE (as writer)', :created, { expected_json_path: 'data/is_reference' })
  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { reader_token }

    standard_request_options(:post, 'CREATE (as reader)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  # TODO: remove on passing test suite
  # post '/audio_recordings/:audio_recording_id/audio_events' do
  #   parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
  #   parameter :tags_attributes, 'array of valid tag attributes, see tag resource', scope: :audio_event
  #   get_modify_params
  #   let(:raw_post) { { 'audio_event' => post_attributes.merge(post_nested_attributes) }.to_json }
  #   let(:authentication_token) { writer_token }

  #   #standard_request_options(: ,'CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
  #   example 'CREATE (with tags_attributes (one existing tag text, one new) as writer) - 201', document: true do
  #     explanation 'this should create an audio event, including two taggings, one with the newly created tag and one with an existing tag'
  #     tag_count = Tag.count
  #     request = do_request

  #     # expecting two 'taggings'

  #     # check response
  #     opts =
  #       {
  #         expected_status: :created,
  #         expected_method: :post,
  #         expected_response_content_type: 'application/json',
  #         document: document_media_requests
  #       }

  #     opts = acceptance_checks_shared(request, opts)

  #     opts.merge!({ expected_json_path: 'data/taggings/1/tag_id', response_body_content: 'start_time_seconds' })
  #     acceptance_checks_json(opts)

  #     # only one tag should have been created, so new tag count should be one more than old tag count
  #     expect(tag_count).to eq(Tag.count - 1)
  #   end
  # end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :tag_ids, 'array of existing tag ids', scope: :audio_event
    get_modify_params

    let(:raw_post) { { 'audio_event' => post_attributes.merge('tag_ids' => [@tag1.id, @tag2.id]) }.to_json }
    let(:authentication_token) { writer_token }

    # create two existing tags
    before do
      @tag1 = FactoryBot.create(:tag)
      @tag2 = FactoryBot.create(:tag)
    end

    #standard_request_options(: ,'CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
    example 'CREATE (with existing tag_ids as writer) - 201', document: true do
      tag_count = Tag.count
      request = do_request

      # expecting two 'taggings'

      # check response
      opts =
        {
          expected_status: :created,
          expected_method: :post,
          expected_response_content_type: 'application/json',
          document: document_media_requests
        }

      opts = acceptance_checks_shared(request, opts)

      opts.merge!({ expected_json_path: 'data/taggings/1/tag_id', response_body_content: 'start_time_seconds' })
      acceptance_checks_json(opts)

      # only one tag should have been created, so new tag count should be one more than old tag count
      expect(tag_count).to eq(Tag.count)
    end
  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { no_access_token }

    standard_request_options(:post, 'CREATE (as no access user)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { invalid_token }

    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized,
      { expected_json_path: get_json_error_path(:sign_in) })
  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }

    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized,
      { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # UPDATE
  ################################

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:put, 'UPDATE (as admin)', :ok, { expected_json_path: 'data/taggings/0/audio_event_id' })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:put, 'UPDATE (as owner)', :ok, { expected_json_path: 'data/taggings/0/audio_event_id' })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer)', :ok, { expected_json_path: 'data/taggings/0/audio_event_id' })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:put, 'UPDATE (as writer with shallow path)', :ok,
      { expected_json_path: 'data/taggings/0/audio_event_id' })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE (as no access user)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:put, 'UPDATE (with invalid token)', :unauthorized,
      { expected_json_path: get_json_error_path(:sign_in) })
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    get_modify_params
    let(:raw_post) { { 'audio_event' => post_attributes }.to_json }
    standard_request_options(:put, 'UPDATE (as anonymous user)', :unauthorized,
      { remove_auth: true, expected_json_path: get_json_error_path(:sign_in) })
  end

  ################################
  # DELETE
  ################################

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { admin_token }

    standard_request_options(:delete, 'DELETE (as admin user)', :no_content,
      { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { owner_token }

    standard_request_options(:delete, 'DELETE (as owner)', :no_content,
      { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { writer_token }

    standard_request_options(:delete, 'DELETE (as writer user)', :no_content,
      { expected_response_has_content: false, expected_response_content_type: nil })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { reader_token }

    standard_request_options(:delete, 'DELETE (as reader user)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { no_access_token }

    standard_request_options(:delete, 'DELETE (as other user)', :forbidden,
      { expected_json_path: get_json_error_path(:permissions) })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    let(:authentication_token) { invalid_token }

    standard_request_options(:delete, 'DELETE (with invalid token)', :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) })
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    get_route_params
    standard_request_options(:delete, 'DELETE (as anonymous user)', :unauthorized,
      { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) })
  end

  #####################
  # Filter
  #####################

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'start_time_seconds' => {
            'in' => ['5.2', '7', '100', '4']
          }
        },
        'projection' => {
          'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as reader)', :ok,
      {
        expected_json_path: 'data/0/start_time_seconds',
        data_item_count: 1,
        regex_match: /"in":\["5.2","7","100","[0-9]+"\]/,
        response_body_content: '"start_time_seconds":',
        invalid_content: '"project_ids":[{"id":'
      })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'start_time_seconds' => {
            'in' => ['5.2', '7', '100', '4']
          }
        },
        'projection' => {
          'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as reader)', :ok,
      {
        expected_json_path: 'data/0/start_time_seconds',
        data_item_count: 1,
        regex_match: [
          /"taggings":\[\{"id":\d+,"audio_event_id":\d+,/,
          /"created_at":"[^"]+"/,
          /"updated_at":"[^"]+"/,
          /"creator_id":\d+/,
          /"updater_id":null/
        ],
        response_body_content: '"taggings":[{"',
        invalid_content: '"taggings":["'
      })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'start_time_seconds' => {
            'in' => ['5.2', '7', '100', '4']
          }
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (no projection, as reader)', :ok,
      {
        expected_json_path: 'data/0/high_frequency_hertz',
        data_item_count: 1,
        regex_match: /"in":\["5.2","7","100","[0-9]+"\]/,
        response_body_content: '"low_frequency_hertz":400.0',
        invalid_content: '"project_ids":[{"id":'
      })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      '{"filter":{"start_time_seconds":{"in":["5.2", "7", "100", "4"]}},"paging":{"items":10,"page":1},"sorting":{"orderBy":"durationSeconds","direction":"desc"}}'
    }

    standard_request_options(:post, 'FILTER (sort by custom field, as reader)', :ok,
      {
        expected_json_path: 'meta/sorting/order_by',
        data_item_count: 1,
        regex_match: /"in":\["5.2","7","100","[0-9]+"\]/,
        response_body_content: ['"low_frequency_hertz":400.0', '"order_by":"duration_seconds"'],
        invalid_content: '"project_ids":[{"id":'
      })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'start_time_seconds' => {
            'lt' => 2.5
          },
          'end_time_seconds' => {
            'gt' => 1
          }
        }
      }.to_json
    }

    before do
      #won't be included
      @ar_1 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 0, end_time_seconds: 1)
      #won't be included
      @ar_2 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 2.5, end_time_seconds: 5)
      #will be included
      @ar_3 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 0, end_time_seconds: 2)
      #will be included
      @ar_4 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 2, end_time_seconds: 4)
      #will be included
      @ar_5 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 1, end_time_seconds: 2.5)
      #will be included
      @ar_6 = FactoryBot.create(:audio_event,
        audio_recording: writer_permission.project.sites[0].audio_recordings[0],
        start_time_seconds: 1.5, end_time_seconds: 2)
    end

    example 'FILTER (overlapping start and end filter)', document: true do
      do_request
      expect(status).to eq(200)

      json = JsonSpec::Helpers.parse_json(response_body)

      # should only return four
      expect(json['meta']['paging']['total']).to eq(4)

      sorted_data = json['data'].sort { |x, y| x['start_time_seconds'] <=> y['start_time_seconds'] }

      expect(sorted_data.size).to eq(4)
      expect(sorted_data[0]['id']).to eq(@ar_3.id)
      expect(sorted_data[1]['id']).to eq(@ar_5.id)
      expect(sorted_data[2]['id']).to eq(@ar_6.id)
      expect(sorted_data[3]['id']).to eq(@ar_4.id)
    end
  end

  context 'filter with paging' do
    post '/audio_events/filter' do
      let(:authentication_token) { reader_token }
      let!(:new_audio_event) {
        30.times do
          audio_event_2 = Creation::Common.create_audio_event(writer_user, audio_recording)
          audio_event_2.is_reference = true
          audio_event_2.save!
        end
      }
      let(:raw_post) {
        { 'filter' => { 'is_reference' => { 'eq' => true } }, 'paging' => { 'items' => 10, 'page' => 2 } }.to_json
      }

      create_entire_hierarchy

      standard_request_options(:post, 'FILTER (as reader, page 2 showing 10 items', :ok,
        {
          expected_json_path: 'data/0/is_reference',
          data_item_count: 10,
          response_body_content: [
            '"paging":{"page":2,"items":10,"total":30,"max_page":3',
            '"previous":"http://localhost:3000/audio_events/filter?direction=desc\u0026items=10\u0026order_by=created_at\u0026page=1"'
          ]
        })
    end
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'audio_events_tags.tag_id' => {
            'gt' => 0
          }
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as reader, for associated table with mismatching name)', :ok,
      {
        expected_json_path: 'data/0/taggings/0/audio_event_id',
        data_item_count: 1,
        response_body_content: '"filter":{"audio_events_tags.tag_id":{"gt":0}},"sorting":{"order_by":"created_at","direction":"desc"},"paging":{"page":1,"items":25,"total":1,"max_page":1,"current":"http://localhost:3000/audio_events/filter?direction=desc\u0026items=25\u0026order_by=created_at\u0026page=1"'
      })
  end

  post '/audio_events/filter' do
    let(:raw_post) {
      {
        'filter' => {
          'audio_events_tags.tag_id' => {
            'gt' => 0
          }
        }
      }.to_json
    }

    standard_request_options(:post, 'FILTER (as anonymous user)', :ok, {
      remove_auth: true,
      response_body_content: '{"meta":{"status":200,"message":"OK","filter":{"audio_events_tags.tag_id":{"gt":0}},"sorting":{"order_by":"created_at","direction":"desc"},"paging":{"page":1,"items":25,"total":0,"max_page":0,"current":"http://localhost:3000/audio_events/filter?direction=desc\u0026items=25\u0026order_by=created_at\u0026page=1","previous":null,"next":null}},"data":[]}'
    })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) {
      {
        'filter' => {
          'isReference' => {
            'eq' => true
          },
          'durationSeconds' => {
            'gteq' => {
              'from' => 0,
              'to' => nil
            }
          },
          'lowFrequencyHertz' => {
            'gteq' => 1100
          }
        },
        'paging' => {
          'items' => 10,
          'page' => 1
        }
      }.to_json
    }

    standard_request_options(
      :post,
      'FILTER (as reader, with invalid nil for gteq interval)',
      :bad_request,
      {
        response_body_content: '{"meta":{"status":400,"message":"Bad Request","error":{"details":"Filter parameters were not valid: The value for (custom item) must not be a hash (unless its underlying type is a hash)","info":null}},"data":null}'
      }
    )
  end
end
