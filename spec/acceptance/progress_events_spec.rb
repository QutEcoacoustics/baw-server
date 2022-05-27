# frozen_string_literal: true

require 'rspec_api_documentation/dsl'
require 'support/acceptance_spec_helper'

def progress_event_id_param
  parameter :progress_event_id, 'Progress Event id in request url', required: true
end

def body_params
  parameter :activity, 'type of progress event', scope: :progress_event, required: true
  parameter :dataset_item_id, 'id of dataset item', scope: :progress_event, required: true
end

def body_params_2
  parameter :activity, 'type of progress event', scope: :progress_event, required: true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'ProgressEvents' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  # Create post parameters from factory
  # add the audio recording id as a post parameter
  let(:post_attributes) {
    post_attributes = FactoryBot.attributes_for(:progress_event)
    post_attributes[:dataset_item_id] = dataset_item[:id]
    post_attributes
  }

  # create some progress events
  #
  # After this, the dataset_items and progress events are:
  # - 1 dataset item created by writer_user (create_entire_hierarchy)
  #   - with 1 progress event created by no_access_user
  # - 1 dataset item in the default dataset, created by writer_user
  #   - with 1 progress event created by admin_user
  # - 1 dataset item created by create_no_access_hierarchy
  #   - with 1 progress event, created by a different user
  # -> 3 progress events total

  create_no_access_hierarchy

  ################################
  # INDEX
  ################################

  # users have read access on progress events if they have read
  # access on the project via project/site/audio_recording/dataset_item/progress_event
  # or if they are the creator

  get '/progress_events' do
    let(:authentication_token) { admin_token }

    standard_request_options(
      :get,
      'INDEX (as admin)',
      :ok,
      { expected_json_path: 'data/0/dataset_item_id', data_item_count: 3 }
    )
  end

  # permissions for owner, writer and reader are the same as each other
  non_admin_opts = { expected_json_path: 'data/0/dataset_item_id', data_item_count: 2 }

  get '/progress_events' do
    let(:authentication_token) { owner_token }

    standard_request_options(:get, 'INDEX (as owner)', :ok, non_admin_opts)
  end

  get '/progress_events' do
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'INDEX (as writer)', :ok, non_admin_opts)
  end

  get '/progress_events' do
    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'INDEX (as reader)', :ok, non_admin_opts)
  end

  get '/progress_events' do
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :get,
      'INDEX (as no access user)',
      :ok,
      { response_body_content: ['"order_by":"created_at","direction":"desc"'], data_item_count: 0 }
    )
  end

  get '/progress_events' do
    let(:authentication_token) { invalid_token }

    standard_request_options(
      :get,
      'INDEX (invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  get '/progress_events' do
    standard_request_options(
      :get,
      'INDEX (as anonymous user)',
      :ok,
      {
        remove_auth: true,
        response_body_content: ['"order_by":"created_at","direction":"desc"'],
        data_item_count: 0
      }
    )
  end

  get '/progress_events' do
    let(:authentication_token) { harvester_token }

    standard_request_options(
      :get,
      'INDEX (as harvester)',
      :forbidden,
      { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
    )
  end

  ################################
  # CREATE
  ################################

  # any user can create a progress event they have read-access on the project

  create_success_opts = { expected_json_path: 'data/activity/', response_body_content: ['"activity":"viewed"'] }

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { admin_token }

    standard_request_options(
      :post,
      'CREATE (as admin)',
      :created,
      create_success_opts
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { owner_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (as owner)',
      :created,
      create_success_opts
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { writer_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (as writer)',
      :created,
      create_success_opts
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { reader_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (as reader)',
      :created,
      create_success_opts
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { no_access_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (no access user)',
      :forbidden,
      { expected_json_path: get_json_error_path(:permissions) }
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { invalid_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (as anonymous user)',
      :unauthorized,
      { remove_auth: true, expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  post '/progress_events' do
    body_params
    let(:raw_post) { { 'progress_event' => post_attributes }.to_json }
    let(:authentication_token) { harvester_token }
    let(:dataset_item_id) { dataset_item.id }

    standard_request_options(
      :post,
      'CREATE (as harvester)',
      :forbidden,
      { expected_json_path: get_json_error_path(:permissions) }
    )
  end

  ################################
  # CREATE BY DATASET ITEM PARAMS
  ################################

  # any user can create a progress event if they have read-access on the project

  context 'CREATE BY DATASET ITEM PARAMS' do
    create_success_opts = { expected_json_path: 'data/activity/', response_body_content: ['"activity":"viewed"'] }

    let(:post_attributes_2) {
      post_attributes_2 = FactoryBot.attributes_for(:progress_event)
      post_attributes_2 = post_attributes_2.except(:dataset_item_id)
      post_attributes_2
    }

    create_by_dataset_item_params_url = '/datasets/:dataset_id/progress_events/audio_recordings/:audio_recording_id/start/:start_time_seconds/end/:end_time_seconds'

    post create_by_dataset_item_params_url do
      let(:authentication_token) { admin_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as admin)',
        :created,
        create_success_opts
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { owner_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as owner)',
        :created,
        create_success_opts
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { writer_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as writer)',
        :created,
        create_success_opts
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { reader_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as reader)',
        :created,
        create_success_opts
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { no_access_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as no access user)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { invalid_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post create_by_dataset_item_params_url do
      body_params_2
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      standard_request_options(
        :post,
        'CREATE (anonymous user)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    post create_by_dataset_item_params_url do
      let(:authentication_token) { harvester_token }
      let(:raw_post) { { 'progress_event' => post_attributes_2 }.to_json }
      let(:dataset_id) { 'default' }
      let(:audio_recording_id) { audio_recording.id }
      let(:start_time_seconds) { 1234 }
      let(:end_time_seconds) { 1245 }

      body_params_2

      standard_request_options(
        :post,
        'CREATE (as harvester)',
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  # ################################
  # # NEW
  # ################################

  get '/progress_events/new' do
    let(:authentication_token) { admin_token }

    standard_request_options(
      :get,
      'NEW (as admin)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { owner_token }

    standard_request_options(
      :get,
      'NEW (as owner)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { writer_token }

    standard_request_options(
      :get,
      'NEW (as writer)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { reader_token }

    standard_request_options(
      :get,
      'NEW (as reader)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :get,
      'NEW (as reader)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { invalid_token }

    standard_request_options(
      :get,
      'NEW (with invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  get '/progress_events/new' do
    standard_request_options(
      :get,
      'NEW (as anonymous user)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/new' do
    let(:authentication_token) { harvester_token }

    standard_request_options(
      :get,
      'NEW (as harvester)',
      :forbidden,
      { expected_json_path: get_json_error_path(:permissions) }
    )
  end

  # ################################
  # # SHOW
  # ################################

  show_success_opts = { expected_json_path: ['data/activity'], response_body_content: ['"activity":"viewed"'] }

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { admin_token }

    standard_request_options(
      :get,
      'SHOW (as admin)',
      :ok,
      { expected_json_path: 'data/activity' }
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { owner_token }

    standard_request_options(
      :get,
      'SHOW (as owner)',
      :ok,
      show_success_opts
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { writer_token }

    standard_request_options(
      :get,
      'SHOW (as writer)',
      :ok,
      show_success_opts
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { reader_token }

    standard_request_options(
      :get,
      'SHOW (as reader)',
      :ok,
      show_success_opts
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :get,
      'SHOW (as no access user)',
      :forbidden,
      { expected_json_path: get_json_error_path(:permissions) }
    )
  end

  # does not have access to the dataset item, but created the progress event
  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event_for_no_access_user.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :get,
      'SHOW (as no access user on progress event created by this user)',
      :ok,
      { expected_json_path: ['data/activity'], response_body_content: ['"activity":"played"'] }
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { no_access_progress_event.id }
    let(:authentication_token) { owner_token }

    standard_request_options(
      :get,
      'SHOW (as no access user) 2',
      :forbidden,
      { expected_json_path: get_json_error_path(:permissions) }
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(
      :get,
      'SHOW (with invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }

    standard_request_options(
      :get,
      'SHOW (an anonymous user)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  get '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { harvester_token }

    standard_request_options(
      :get,
      'SHOW (an anonymous user)',
      :forbidden,
      { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
    )
  end

  # ################################
  # # UPDATE
  # ################################

  # only admin can update

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(
      :put,
      'UPDATE (as admin)',
      :ok,
      { expected_json_path: 'data/activity/', response_body_content: '"activity":"played"' }
    )
  end

  forbidden_opts = { expected_json_path: get_json_error_path(:permissions) }

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(
      :put,
      'UPDATE (as owner)',
      :forbidden,
      forbidden_opts
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(
      :put,
      'UPDATE (as writer)',
      :forbidden,
      forbidden_opts
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(
      :put,
      'UPDATE (as reader)',
      :forbidden,
      forbidden_opts
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(
      :put,
      'UPDATE (as no access user)',
      :forbidden,
      forbidden_opts
    )
  end

  # can not update the progress event, even through is the creator
  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event_for_no_access_user.id }
    let(:raw_post) { { progress_event: { activity: 'viewed' } }.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(
      :put,
      'UPDATE (as no access user)',
      :forbidden,
      forbidden_opts
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(
      :put,
      'UPDATE (as invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    standard_request_options(
      :put,
      'UPDATE (as not logged in)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  put '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:raw_post) { { progress_event: { activity: 'played' } }.to_json }
    let(:authentication_token) { harvester_token }
    standard_request_options(
      :put,
      'UPDATE (as harvester)',
      :forbidden,
      forbidden_opts
    )
  end

  # ################################
  # # DESTROY
  # ################################

  # only admin can destroy

  delete '/progress_events/:id' do
    progress_event_id_param
    let(:id) { progress_event.id }
    let(:authentication_token) { admin_token }

    standard_request_options(
      :delete,
      'DELETE (as admin user)',
      :no_content,
      { expected_response_has_content: false, expected_response_content_type: nil }
    )
  end

  forbidden_opts = { expected_json_path: get_json_error_path(:permissions) }

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { owner_token }

    standard_request_options(
      :delete,
      'DELETE (as owner)',
      :forbidden, forbidden_opts
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { writer_token }

    standard_request_options(
      :delete,
      'DELETE (as writer)',
      :forbidden, forbidden_opts
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { reader_token }

    standard_request_options(
      :delete,
      'DELETE (as reader)',
      :forbidden,
      forbidden_opts
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :delete,
      'DELETE (as no access user)',
      :forbidden,
      forbidden_opts
    )
  end

  # can not delete the progress event, even through is the creator
  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event_for_no_access_user.id }
    let(:authentication_token) { no_access_token }

    standard_request_options(
      :delete,
      'DELETE (as no access user)',
      :forbidden,
      forbidden_opts
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { invalid_token }

    standard_request_options(
      :delete,
      'DELETE (as invalid token)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }

    standard_request_options(
      :delete,
      'DELETE (as not logged in)',
      :unauthorized,
      { expected_json_path: get_json_error_path(:sign_up) }
    )
  end

  delete '/progress_events/:id' do
    progress_event_id_param
    body_params
    let(:id) { progress_event.id }
    let(:authentication_token) { harvester_token }

    standard_request_options(
      :delete,
      'DELETE (as harvester)',
      :forbidden, forbidden_opts
    )
  end

  # ################################
  # # FILTER
  # ################################

  context 'filter progress events' do
    # creates 40 progress events in addition to the existing 3
    # This includes 8 that use the no_access_dataset_item (4 of each activity)
    # So, with the original 3, there are 9 out of 43 that only admin user should find
    # leaving 34 that other users (owner, reader, writer) should find
    # One progress event is created by the no access user with the main dataset item. This user should
    # therefore find that progress event only
    prepare_many_progress_events

    # admin finds all items (1 full page)
    post '/progress_events/filter' do
      let(:authentication_token) { admin_token }

      standard_request_options(
        :post,
        'FILTER (as admin)',
        :ok,
        {
          response_body_content: ['"activity":"viewed"'],
          expected_json_path: 'data/0/dataset_item_id',
          data_item_count: 25
        }
      )
    end

    # admin finds all items
    post '/progress_events/filter' do
      let(:authentication_token) { admin_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(
        :post,
        'FILTER (as admin)',
        :ok,
        {
          response_body_content: ['"activity":"viewed"'],
          expected_json_path: 'data/0/dataset_item_id',
          data_item_count: 43
        }
      )
    end

    # permissions will be the same for reader, writer, owner so they will have
    # the same response for the same filter params. Should return all progress events
    # except those for the dataset item from the no-access hierarchy
    regular_user_opts = {
      response_body_content: ['"activity":"viewed"'],
      expected_json_path: 'data/0/dataset_item_id',
      data_item_count: 34
    }

    post '/progress_events/filter' do
      let(:authentication_token) { owner_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(:post, 'FILTER (as owner)', :ok, regular_user_opts)
    end

    post '/progress_events/filter' do
      let(:authentication_token) { writer_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(:post, 'FILTER (as writer)', :ok, regular_user_opts)
    end

    post '/progress_events/filter' do
      let(:authentication_token) { reader_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(:post, 'FILTER (as reader)', :ok, regular_user_opts)
    end

    # no-access user is the creator of 1 progress event for a dataset_item that
    # this user does not have access to. User can not access the record even if
    # they are creator
    post '/progress_events/filter' do
      let(:authentication_token) { no_access_token }

      standard_request_options(
        :post,
        'FILTER (as no access)',
        :ok,
        { response_body_content: ['"order_by":"created_at"'], expected_json_path: 'data', data_item_count: 0 }
      )
    end

    post '/progress_events/filter' do
      let(:authentication_token) { invalid_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(
        :post,
        'FILTER (as invalid token)',
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end

    # not logged in users can filter dataset items, but they won't get any items that they don't have permission for
    post '/progress_events/filter' do
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(
        :post,
        'FILTER (as not logged in)',
        :ok,
        { response_body_content: ['"order_by":"created_at"'], expected_json_path: 'data', data_item_count: 0 }
      )
    end

    post '/progress_events/filter' do
      let(:authentication_token) { harvester_token }
      let(:raw_post) { { 'paging' => { 'items' => 100 } }.to_json }

      standard_request_options(
        :post,
        'FILTER (as harvester)',
        :forbidden,
        { response_body_content: ['"data":null'], expected_json_path: get_json_error_path(:permissions) }
      )
    end

    # find only the "viewed" progress events
    # out of the 33 accessible progress events, half + 1 are "viewed" = 17
    post '/progress_events/filter' do
      let(:authentication_token) { reader_token }
      let(:raw_post) {
        {
          'filter' => {
            'activity' => {
              'eq' => 'viewed'
            }
          },
          'projection' => {
            'include' => ['id', 'dataset_item_id', 'creator_id', 'created_at']
          }
        }.to_json
      }

      standard_request_options(
        :post,
        'FILTER (as reader) where activity is "viewed"',
        :ok,
        {
          expected_json_path: 'data/0/creator_id',
          data_item_count: 17,
          response_body_content: '"created_at":',
          # activity is included in the projection
          # the leading comma ensures we are looking in the data not meta
          invalid_content: ',"activity":'
        }
      )
    end

    # find only the progress events created by owner or writer
    # out of the 32 new progress non-no_access progress events, an equal amount were
    # created by each user = 16 expected items
    post '/progress_events/filter' do
      let(:authentication_token) { admin_token }
      let(:raw_post) {
        {
          'filter' => {
            'creator_id' => {
              'in' => [owner_user.id, writer_user.id]
            }
          }
        }.to_json
      }

      standard_request_options(
        :post,
        'FILTER (as admin) where creator is owner or writer',
        :ok,
        {
          expected_json_path: 'data/0/creator_id',
          data_item_count: 16,
          response_body_content: '"created_at":'
        }
      )
    end

    # filter progress events by dataset id
    post '/progress_events/filter' do
      let(:authentication_token) { reader_token }
      let(:raw_post) {
        {
          'filter' => {
            'datasets.id' => {
              'eq' => dataset.id
            }
          }
        }.to_json
      }

      standard_request_options(
        :post,
        'FILTER (as reader) by dataset id',
        :ok,
        {
          expected_json_path: 'data/0/creator_id',
          response_body_content: '"created_at":'
        }
      ) do |example, opts|
        opts[:data_item_count] = [
          25, # page size
          example.dataset.dataset_items.map { |di| di.progress_events.count }.sum
        ].min
      end
    end
  end
end
