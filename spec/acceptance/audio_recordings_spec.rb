require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'AudioRecordings' do

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
    @user = FactoryGirl.create(:user)
    @harvester = FactoryGirl.create(:harvester)
  end

  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:site_id) { @write_permission.project.sites[0].id }
  let(:id) { @write_permission.project.sites[0].audio_recordings[0].id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:no_access_token) { "Token token=\"#{@user.authentication_token}\"" }
  let(:harvester_token) { "Token token=\"#{@harvester.authentication_token}\"" }


  # Create post parameters from factory
  # make sure the uploader has write permission to the project
  let(:post_attributes) { FactoryGirl.attributes_for(:all_audio_recording_attributes, uploader_id: @write_permission.user.id) }

  ################################
  # LIST
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('LIST (as reader)', 200, '0/bit_rate_bps', true)

  end

  get '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('LIST (as writer)', 200, '0/bit_rate_bps', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID\"" }
    standard_request('LIST (with invalid token)', 401, nil, true)
  end

  ################################
  # SHOW
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader)', 200, 'bit_rate_bps', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('SHOW (as writer)', 200, 'bit_rate_bps', true)

  end

  get '/audio_recordings/:id' do

    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { no_access_token }

    standard_request('SHOW (as no access, with shallow path)', 403, nil, true)
  end

  get '/audio_recordings/:id' do

    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader, with shallow path)', 200, 'bit_rate_bps', true)
  end

  get '/audio_recordings/:id' do

    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('SHOW (as writer, with shallow path)', 200, 'bit_rate_bps', true)

  end

  ################################
  # NEW
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/new' do

    let(:authentication_token) { harvester_token }

    standard_request('NEW (as harvester)', 200, 'bit_rate_bps', true)

  end

  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    parameter :bit_rate_bps, '', scope: :audio_recording, :required => true
    parameter :channels, '', scope: :audio_recording
    parameter :data_length_bytes, '', scope: :audio_recording
    parameter :duration_seconds, '', scope: :audio_recording, :required => true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :media_type, '', scope: :audio_recording
    parameter :notes, '', scope: :audio_recording
    parameter :recorded_date, '', scope: :audio_recording
    parameter :sample_rate_hertz, '', scope: :audio_recording, :required => true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { harvester_token }

    # Execute request with ids defined in above let(:id) statements
    example "'CREATE (as harvester)' - 201", document: true do
      do_request
      status.should eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
      response_body.should have_json_path('bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

      AudioRecording.count.should eq(2)
      AudioRecording.order(:created_at).first.status.should eq('ready')
      AudioRecording.order(:created_at).offset(1).first.status.should eq('new')
    end

  end

  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('CREATE (as writer)', 403, nil, true)

  end

  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request('CREATE (as reader)', 403, nil, true)

  end

  ################################
  # CHECK_UPLOADER
  ################################
  put '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @write_permission.user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('CHECK_UPLOADER (as harvester checking writer)', 204, nil, true)
  end

  put '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @write_permission.user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }
    standard_request('CHECK_UPLOADER (as writer checking writer)', 406, nil, true)
  end

  put '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('CHECK_UPLOADER (as harvester checking no access)', 406, nil, true)
  end

  ################################
  # UPDATE_STATUS
  ################################
  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => {'file_hash' => @write_permission.project.sites[0].audio_recordings[0].file_hash,
                                            'uuid' => @write_permission.project.sites[0].audio_recordings[0].uuid}}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester)', 204, nil, true)
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => {'file_hash' => @write_permission.project.sites[0].audio_recordings[0].file_hash,
                                            'uuid' => nil}}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester without uuid)', 422, 'error', true)
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => {'file_hash' => @write_permission.project.sites[0].audio_recordings[0].file_hash,
                                            'uuid' => @write_permission.project.sites[0].audio_recordings[0].uuid}}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('UPDATE STATUS (writer)', 403, nil, true)

  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => {'file_hash' => @write_permission.project.sites[0].audio_recordings[0].file_hash,
                                            'uuid' => @write_permission.project.sites[0].audio_recordings[0].uuid}}.to_json }
    let(:authentication_token) { reader_token }

    standard_request('UPDATE STATUS (as reader)', 403, nil, true)

  end


end