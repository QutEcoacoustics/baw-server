require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'


# https://github.com/zipmark/rspec_api_documentation
resource 'AudioEvents' do
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
    @admin_user = FactoryGirl.create(:admin)
  end


  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:site_id) { @write_permission.project.sites[0].id }
  let(:audio_recording_id) { @write_permission.project.sites[0].audio_recordings[0].id }
  let(:id) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0].id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }


  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:audio_event) }
  let(:post_nested_attributes) {
    {'tags_attributes' => [FactoryGirl.attributes_for(:tag),
                           {:is_taxanomic => @existing_tag.is_taxanomic, :text => @existing_tag.text, :type_of_tag => @existing_tag.type_of_tag, :retired => @existing_tag.retired}]
    }
  }

  ################################
  # LIST
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { writer_token }

    standard_request('LIST (as writer)', 200, '0/start_time_seconds', true)

  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }

    standard_request('LIST (as reader)', 200, '0/start_time_seconds', true)

  end


  get '/audio_recordings/:audio_recording_id/audio_events' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }

    standard_request('LIST (as reader with shallow path)', 200, '0/start_time_seconds', true)

  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events?start_offset=1&end_offset=2.5' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }
    # create three audio_events with times 1 - 4, 2 - 4, 3 - 4
    before do
      #won't be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 0, end_time_seconds: 1)
      #won't be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 2.5, end_time_seconds: 5)
      #will be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 0, end_time_seconds: 2)
      #will be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 2, end_time_seconds: 4)
      #will be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 1, end_time_seconds: 2.5)
      #will be included
      FactoryGirl.create(:audio_event,
                         audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                         start_time_seconds: 1.5, end_time_seconds: 2)
    end

    example 'LIST (with offsets as reader) - 200', :document => true do
      do_request
      status.should == 200
      response_body.should have_json_path('1/start_time_seconds')
      # should only return four
      response_body.should have_json_size(4)
      # TODO: check the values of the events that are returned
    end
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { unconfirmed_token }

    standard_request('LIST (as unconfirmed user)', 401, nil, true)

  end

  ################################
  # LIBRARY
  ################################
  get '/audio_events/library' do
    let(:authentication_token) { writer_token }
    standard_request('LIST (as writer)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { reader_token }
    standard_request('LIST (as reader)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { admin_token }
    standard_request('LIST (as admin)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { unconfirmed_token }
    standard_request('LIST (as unconfirmed user)', 401, nil, true)
  end

  ################################
  # SHOW
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('SHOW (as writer)', 200, 'start_time_seconds', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader)', 200, 'start_time_seconds', true)
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader with shallow path)', 200, 'start_time_seconds', true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do

    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token }

    standard_request('SHOW (as unconfirmed user)', 401, nil, true)
  end

  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('CREATE (as writer)', 201, nil, true)

  end

  post 'audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('CREATE (as writer with shallow path)', 201, nil, true)

  end

  post '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request('CREATE (as reader)', 403, nil, true)

  end

  post '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { unconfirmed_token }

    standard_request('CREATE (as unconfirmed user)', 401, nil, true)

  end

  post '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event
    parameter :tags_attributes, 'array of valid tag attributes, see tag resource', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes.merge(post_nested_attributes)}.to_json }
    let(:authentication_token) { writer_token }

    #standard_request('CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
    example 'CREATE (with tags_attributes (one existing tag text, one new) as writer) - 201', :document => true do
      explanation 'this should create an audiorecording, including two taggings, one with the newly created tag and one with an existing tag'
      tag_count = Tag.count
      do_request
      tag_count.should == Tag.count - 1
      status.should == 201
      response_body.should have_json_path('start_time_seconds')
      response_body.should have_json_path('taggings/1/tag')
    end
  end

  post '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event
    parameter :tag_ids, 'array of existing tag ids', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes.merge("tag_ids" => [@tag1.id, @tag2.id])}.to_json }
    let(:authentication_token) { writer_token }

    # create two existing tags
    before do
      @tag1 = FactoryGirl.create(:tag)
      @tag2 = FactoryGirl.create(:tag)
    end

    #standard_request('CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
    example 'CREATE (with existing tag_ids as writer) - 201', :document => true do
      tag_count = Tag.count
      do_request
      tag_count.should == Tag.count
      status.should == 201
      response_body.should have_json_path('start_time_seconds')
      response_body.should have_json_path('taggings/1/tag') # expecting two 'taggings'
    end
  end

  ################################
  # UPDATE
  ################################
  put '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('UPDATE (as writer)', 201, nil, true)
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('UPDATE (as writer with shallow path)', 201, nil, true)
  end

  put '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request('UPDATE (as reader)', 403, nil, true)
  end

  put '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { unconfirmed_token }

    standard_request('UPDATE (as unconfirmed user)', 401, nil, true)
  end
end