require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Tags' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format)                {'json'}

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
  end

  # prepare ids needed for paths in requests below
  let(:project_id)            {@write_permission.project.id}
  let(:site_id)               {@write_permission.project.sites[0].id}
  let(:audio_recording_id)    {@write_permission.project.sites[0].audio_recordings[0].id}
  let(:audio_event_id)        {@write_permission.project.sites[0].audio_recordings[0].audio_events[0].id}
  let(:id)                    {@write_permission.project.sites[0].audio_recordings[0].audio_events[0].tags[0].id}

  # prepare authentication_token for different users
  let(:writer_token)          {"Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token)          {"Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token)     {"Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:confirmed_token)     {"Token token=\"#{FactoryGirl.create(:confirmed_user).authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) {FactoryGirl.attributes_for(:required_tag_attributes)}

  ################################
  # LIST
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    # Execute request with ids defined in above let(:id) statements
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { writer_token}
    standard_request('LIST for audio_event (as writer)', 200, '0/is_taxanomic', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    # Execute request with ids defined in above let(:id) statements
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { reader_token}
    standard_request('LIST for audio_event (as reader)', 200, '0/is_taxanomic', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags' do
    # Execute request with ids defined in above let(:id) statements
    parameter :project_id, 'Accessed project ID (in path/route)', required: true
    parameter :site_id, 'Accessed site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording ID (in path/route)', required: true
    parameter :audio_event_id, 'Requested audio event ID (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token}
    standard_request('LIST for audio_event (as unconfirmed user)', 401, nil, true)
  end

  get '/tags' do
    let(:authentication_token) { confirmed_token}

    # should list 2 tags in the list
    #standard_request('LIST (as confirmed user)', 200, '0/is_taxanomic', true)
    example 'LIST ALL (as confirmed user) - 200', :document => true do
      # create orphaned tags
      2.times do |i|
        FactoryGirl.create(:tag)
      end

      do_request
      status.should == 200
      response_body.should have_json_path('2/is_taxanomic')
    end
  end

  ################################
  # SHOW
  ################################
  get  '/tags/:id' do
    parameter :id, 'Requested tag ID (in path/route)', required: true

    let(:authentication_token) { writer_token}
    standard_request('SHOW (as writer)', 200, 'is_taxanomic', true)
  end

  get  '/tags/:id' do
    parameter :id, 'Requested tag ID (in path/route)', required: true

    let(:authentication_token) { reader_token}
    standard_request('SHOW (as reader)', 200, 'is_taxanomic', true)
  end

  ################################
  # CREATE
  ################################
  post '/tags' do
    # Documentation in rspec_api_documentation
    parameter :is_taxanomic, 'is taxanomic', scope: :tag, required: true
    parameter :text, 'text', scope: :tag    , required: true
    parameter :type_of_tag, 'choose from [general, common_name, species_name, looks_like, sounds_like]', scope: :tag, :required => true
    parameter :retired, 'true or false', scope: :tag, :required => true

    let(:raw_post) { {'tag' => post_attributes}.to_json }

    let(:authentication_token) { writer_token}
    standard_request('CREATE (as writer)', 201, 'is_taxanomic', true)
  end


  post '/tags' do
    # Documentation in rspec_api_documentation
    parameter :is_taxanomic, 'is taxanomic', scope: :tag, required: true
    parameter :text, 'text', scope: :tag    , required: true
    parameter :type_of_tag, 'choose from [general, common_name, species_name, looks_like, sounds_like]', scope: :tag, :required => true
    parameter :retired, 'true or false', scope: :tag, :required => true

    let(:raw_post) { {'tag' => post_attributes}.to_json }

    let(:authentication_token) { unconfirmed_token}
    # TODO: check what the result should be
    standard_request('CREATE (as unconfirmed user)', 401, nil, true)
  end

end