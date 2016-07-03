require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def tag_id_param
  parameter :id, 'Requested tag ID (in path/route)', required: true
end

def tag_extras_id_params
  parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
  parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true
end

def tag_body_params
  parameter :is_taxanomic, 'is taxanomic', scope: :tag, required: true
  parameter :text, 'text', scope: :tag, required: true
  parameter :type_of_tag, 'choose from [general, common_name, species_name, looks_like, sounds_like]', scope: :tag, required: true
  parameter :retired, 'true or false', scope: :tag, required: true
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Tags' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  # prepare ids needed for paths in requests below
  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:audio_recording_id) { audio_recording.id }
  let(:audio_event_id) { audio_event.id }
  let(:id) { tag.id }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:tag) }

  ################################
  # INDEX
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST for audio_event (as admin)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'LIST for audio_event (as owner)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST for audio_event (as writer)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST for audio_event (as reader)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST for audio_event (as no access user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST for audio_event (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    tag_extras_id_params
    standard_request_options(:get, 'LIST for audio_event (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # INDEX SHALLOW
  ################################

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST for audio_event (as admin, shallow route)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'LIST for audio_event (as owner, shallow route)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST for audio_event (as writer, shallow route)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST for audio_event (as reader, shallow route)', :ok, {expected_json_path: 'data/0/is_taxanomic', data_item_count: 1})
  end

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'LIST for audio_event (as no access user, shallow route)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  get '/tags' do
    tag_extras_id_params
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST for audio_event (with invalid token, shallow route)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/tags' do
    tag_extras_id_params
    standard_request_options(:get, 'LIST for audio_event (as anonymous user, shallow route)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # NEW
  ################################

  get '/tags/new' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'NEW for audio_event (as admin)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/new' do
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'NEW for audio_event (as owner)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/new' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'NEW for audio_event (as writer)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/new' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW for audio_event (as reader)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/new' do
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'NEW for audio_event (as no access user)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW for audio_event (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/tags/new' do
    standard_request_options(:get, 'NEW for audio_event (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_in)})
  end

  ################################
  # SHOW
  ################################

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'SHOW (as admin)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { owner_token }
    standard_request_options(:get, 'SHOW (as owner)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { no_access_token }
    standard_request_options(:get, 'SHOW (as no access user)', :ok, {expected_json_path: 'data/is_taxanomic'})
  end

  get '/tags/:id' do
    tag_id_param
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'SHOW (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  get '/tags/:id' do
    tag_id_param
    standard_request_options(:get, 'SHOW (as anonymous user)', :ok, {remove_auth: true, expected_json_path: 'data/is_taxanomic'})
  end

  ################################
  # CREATE
  ################################

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/is_taxanomic'})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { owner_token }
    standard_request_options(:post, 'CREATE (as owner)', :created, {expected_json_path: 'data/is_taxanomic'})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/is_taxanomic'})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/is_taxanomic'})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { no_access_token }
    standard_request_options(:post, 'CREATE (as no access user)', :created, {expected_json_path: 'data/is_taxanomic'})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    let(:authentication_token) { invalid_token }
    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_in)})
  end

  post '/tags' do
    tag_body_params
    let(:raw_post) { {'tag' => post_attributes}.to_json }
    standard_request_options(:post, 'CREATE (as anonymous user)', :unauthorized, {remove_auth: true, expected_json_path: get_json_error_path(:sign_up)})
  end

  #####################
  # Filter
  #####################

  post '/tags/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'retired' => {
                'eq' => false
            }
        },
        'projection' => {
            'include' => ['id', 'text', 'is_taxanomic', 'retired']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader, with projection)', :ok,
                             {
                                 expected_json_path: 'data/0/is_taxanomic',
                                 data_item_count: 1,
                                 response_body_content: ["\"retired\":false", '"projection":{"include":["id","text","is_taxanomic","retired"]}']
                             })
  end

  post '/tags/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'type_of_tag' => {
                'eq' => 'general'
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader, simple filter)', :ok,
                             {
                                 expected_json_path: 'data/0/type_of_tag',
                                 data_item_count: 1,
                                 response_body_content: "general",
                                 invalid_content: "\"taggings\":[{\""
                             })
  end


  post '/tags/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) { {
        'filter' => {
            'text' => {
                'contains' => 'tag text'
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as writer, simple projection)', :ok,
                             {
                                 expected_json_path: 'data/0/text',
                                 data_item_count: 1,
                                 response_body_content: ['tag text', "\"filter\":{\"text\":{\"contains\":\"tag text\"}}"]
                             })
  end

  post '/tags/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) { {
        'filter' => {
            'audio_events.id' => {
                'in' => [9999, audio_event_id]
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as writer, audio_events.id )', :ok,
                             {
                                 expected_json_path: 'data/0/text',
                                 data_item_count: 1,
                                 response_body_content: ['audio_events.id', "\"filter\":{\"audio_events.id\":{\"in\":[9999,"]
                             })
  end

  post '/tags/filter' do
    let(:authentication_token) { writer_token }
    let(:raw_post) { {
        'filter' => {
            'AudioEvents.Id' => {
                'in' => [9999, audio_event_id]
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as writer, AudioEvents.Id )', :ok,
                             {
                                 expected_json_path: 'data/0/text',
                                 data_item_count: 1,
                                 response_body_content: ['audio_events.id', "\"filter\":{\"audio_events.id\":{\"in\":[9999,"]
                             })
  end

end