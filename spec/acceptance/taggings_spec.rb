require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Taggings' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
    @existing_tag = FactoryGirl.create(:tag, text: 'existing')
  end

  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:site_id) { @write_permission.project.sites[0].id }
  let(:audio_recording_id) { @write_permission.project.sites[0].audio_recordings[0].id }
  let(:audio_event_id) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0].id }
  let(:id) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0].taggings[0].id }
  let(:user_id) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0].taggings[0].creator_id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) { {tag_id: @existing_tag.id} }
  let(:post_nested_attributes) { {'tag_attributes' => FactoryGirl.attributes_for(:tag)} }
  let(:post_invalid_nested_attributes) { {'tag_attributes' => FactoryGirl.attributes_for(:tag, type_of_tag: 'invalid value')} }

  ################################
  # LIST
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Execute request with ids defined in above let(:id) statements
    parameter :audio_recording_id, 'Accessed audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer, with shallow path)', :ok, {expected_json_path: 'data/0/tag_id', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Execute request with ids defined in above let(:id) statements
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader, with shallow path)', :ok, {expected_json_path: 'data/0/tag_id', data_item_count: 1})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Execute request with ids defined in above let(:id) statements
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed user, with shallow path)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/user_accounts/:user_id/taggings' do
    parameter :user_id, 'Get taggings for user id (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader, user taggings)', :ok, {expected_json_path: 'data/0/tag_id', data_item_count: 1})
  end

  ################################
  # SHOW
  ################################

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested tag ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'SHOW (as writer, with shallow path)', :ok, {expected_json_path: 'data/tag_id'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested tag ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'SHOW (as reader, with shallow path)', :ok, {expected_json_path: 'data/tag_id'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id' do
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested tag ID (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'SHOW (as unconfirmed user, with shallow path)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  ################################
  # CREATE
  ################################

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { {'tagging' => post_attributes}.to_json }


    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (with tag_id as writer, with shallow path)', :created, {expected_json_path: 'data/tag_id'})
  end

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { {'tagging' => post_nested_attributes}.to_json }

    let(:authentication_token) { writer_token }
    standard_request_options(:post, 'CREATE (with tag_attributes as writer, with shallow path)', :created, {expected_json_path: 'data/tag_id'})
  end

  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { {'tagging' => post_invalid_nested_attributes}.to_json }

    let(:authentication_token) { writer_token }
    # 0 - index in array
    standard_request_options(:post, 'CREATE (invalid tag_attributes as writer, with shallow path)', :unprocessable_entity,
                             {expected_json_path: 'type_of_tag', response_body_content: '"is not included in the list"'})
  end


  post '/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings' do
    # Documentation in rspec_api_documentation

    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:raw_post) { {:tagging => {:tag_attributes => {:is_taxanomic => false, :text => @existing_tag.text, :type_of_tag => 'looks like', :retired => false}}}.to_json }

    let(:authentication_token) { writer_token }

    #example 'CREATE (existing tag name as writer) - 200', :document => true do
    #  # create orphaned tags
    #  2.times do |i|
    #    FactoryGirl.create(:tag)
    #  end
    #
    #  do_request
    #  status.should == 200
    #  response_body.should have_json_path('2/is_taxanomic')
    #end
    standard_request_options(:post, 'CREATE (with tag_attributes but existing tag text as writer, with shallow path)', :created,
                             {expected_json_path: 'data/tag_id'})
  end

end