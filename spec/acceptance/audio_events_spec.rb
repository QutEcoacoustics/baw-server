require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'


def library_request(settings = {})
  description = settings[:description]
  expected_status = settings[:expected_status]
  expected_json_path = settings[:expected_json_path]
  document = settings[:document]
  response_body_content = settings[:response_body_content]

  example "#{description} - #{expected_status}", :document => document do
    do_request

    status.should eq(expected_status), "Requested #{path} expecting status #{expected_status} but got status #{status}. Response body was #{response_body}"

    unless expected_json_path.blank?
      response_body.should have_json_path(expected_json_path), "could not find #{expected_json_path} in #{response_body}"
    end

    unless response_body_content.blank?
      expect(response_body).to include(response_body_content)
    end

    parsed_response_body = JsonSpec::Helpers::parse_json(response_body)

    unless ordered_audio_recordings.blank? && parsed_response_body.blank?
      parsed_response_body.each_index do |index|
        expect(parsed_response_body[index]['audio_event_id'])
        .to eq(ordered_audio_recordings[index]),
            "Result body index #{index} in #{ordered_audio_recordings}: #{parsed_response_body}"
      end
      ordered_audio_recordings.each_index do |index|
        expect(ordered_audio_recordings[index])
        .to eq(parsed_response_body[index]['audio_event_id']),
            "Audio Event Order index #{index} in #{ordered_audio_recordings}: #{parsed_response_body}"
      end
    end

  end
end

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
  #  freq diff 5600, duration diff 0.6, start_time_seconds 5.2, low_frequency_hertz 400, high_frequency_hertz 6000, end_time_seconds 5.8
  let(:id) { @write_permission.project.sites[0].audio_recordings[0].audio_events[0].id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:audio_event) }
  let(:post_nested_attributes) {
    {tags_attributes: [
        FactoryGirl.attributes_for(:tag),
        {
            is_taxanomic: @existing_tag.is_taxanomic,
            text: @existing_tag.text,
            type_of_tag: @existing_tag.type_of_tag,
            retired: @existing_tag.retired
        }
    ]}
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
    standard_request('LIBRARY (as writer)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { reader_token }
    standard_request('LIBRARY (as reader)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { admin_token }
    standard_request('LIBRARY (as admin)', 200, '0/start_time_seconds', true)
  end

  get '/audio_events/library' do
    let(:authentication_token) { unconfirmed_token }
    standard_request('LIBRARY (as unconfirmed user)', 401, nil, true)
  end

  ################################
  # LIBRARY FILTERS
  ################################

  get '/audio_events/library' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    let(:ordered_audio_recordings) { [id] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, default annotations)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do

      user_creator = FactoryGirl.create(:user, id: 5)

      koala = FactoryGirl.create(:tag, text: 'koala', creator: user_creator)
      lewin = FactoryGirl.create(:tag, text: 'lewin', creator: user_creator)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      tagging = FactoryGirl.create(:tagging, creator: user_creator, tag: koala, audio_event: ae)
      tagging = FactoryGirl.create(:tagging, creator: user_creator, tag: lewin, audio_event: ae)

    end

    # default sort is 'audio_events.created_at DESC'
    let(:ordered_audio_recordings) { [9991, id] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, one additional annotation)',
            expected_status: 200,
            expected_json_path: '1/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?freqMin=450.3&freqMax=500.2&annotationDuration=0.54' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do

      user_creator = FactoryGirl.create(:user, id: 5)

      koala = FactoryGirl.create(:tag, text: 'koala', creator: user_creator)
      lewin = FactoryGirl.create(:tag, text: 'lewin', creator: user_creator)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 2,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 500.2,
                               is_reference: true,
                               creator: user_creator)

      tagging = FactoryGirl.create(:tagging, creator: user_creator, tag: koala, audio_event: ae)
      tagging = FactoryGirl.create(:tagging, creator: user_creator, tag: lewin, audio_event: ae)
    end

    let(:ordered_audio_recordings) { [9991, 9992, id] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, ordered by bounds: duration)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?freqMin=450.3&freqMax=500.2&annotationDuration=0.54' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do
      user_creator = FactoryGirl.create(:user, id: 5)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 451,
                               high_frequency_hertz: 500.2,
                               is_reference: true,
                               creator: user_creator)

      ae3 = FactoryGirl.create(:audio_event,
                               id: 9993,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 445,
                               high_frequency_hertz: 500.2,
                               is_reference: true,
                               creator: user_creator)
    end

    let(:ordered_audio_recordings) { [9991, 9992, 9993, id] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, ordered by bounds: freqMin)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?freqMin=450.3&freqMax=500.2&annotationDuration=0.54' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do
      user_creator = FactoryGirl.create(:user, id: 5)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 500,
                               is_reference: true,
                               creator: user_creator)

      ae3 = FactoryGirl.create(:audio_event,
                               id: 9993,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 510,
                               is_reference: true,
                               creator: user_creator)
    end

    let(:ordered_audio_recordings) { [9991, 9992, 9993, id] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, ordered by bounds: freqMax)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?userId=99998' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do
      user_creator = FactoryGirl.create(:user, id: 99998)
      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      user_creator2 = FactoryGirl.create(:user, id: 99997)
      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 500,
                               is_reference: true,
                               creator: user_creator2)

    end

    let(:ordered_audio_recordings) { [9991] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, filter by userId)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?reference=true' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do
      user_creator = FactoryGirl.create(:user, id: 5)
      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 1.54,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 500,
                               is_reference: false,
                               creator: user_creator)

    end

    let(:ordered_audio_recordings) { [9991] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, filter by reference)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

  end

  get '/audio_events/library?tagsPartial=koala,lewi' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do

      user_creator = FactoryGirl.create(:user, id: 99999)

      koala = FactoryGirl.create(:tag, text: 'koala', creator: user_creator)
      lewin = FactoryGirl.create(:tag, text: 'lewin', creator: user_creator)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                               id: 9992,
                               audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                               start_time_seconds: 1,
                               end_time_seconds: 2,
                               low_frequency_hertz: 450.3,
                               high_frequency_hertz: 500.2,
                               is_reference: true,
                               creator: user_creator)

      FactoryGirl.create(:tagging, creator: user_creator, tag: koala, audio_event: ae)
      FactoryGirl.create(:tagging, creator: user_creator, tag: lewin, audio_event: ae2)
    end

    # deault sort order is audio_events.created_at DESC
    let(:ordered_audio_recordings) { [9992, 9991] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, two additional, filter by tagsPartial)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })
  end

  get '/audio_events/library?reference=true&tagsPartial=ewi,ala&freqMin=450.3&freqMax=500.2&annotationDuration=0.54&userId=9998&page=1&items=10' do

    parameter :reference, '[true, false] (optional)'
    parameter :tagsPartial, 'comma separated text (optional)'
    parameter :freqMin, 'double (optional)'
    parameter :freqMax, 'double (optional)'
    parameter :annotationDuration, 'double (optional)'
    parameter :page, 'int (optional)'
    parameter :items, 'int (optional)'
    parameter :userId, 'int (optional)'

    let(:authentication_token) { reader_token }

    before do

      user_creator = FactoryGirl.create(:user, id: 9998)
      lewin = FactoryGirl.create(:tag, text: 'lewin', creator: user_creator)
      koala = FactoryGirl.create(:tag, text: 'koala', creator: user_creator)

      ae = FactoryGirl.create(:audio_event,
                              id: 9991,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 500.2,
                              is_reference: true,
                              creator: user_creator)

      ae2 = FactoryGirl.create(:audio_event,
                              id: 9992,
                              audio_recording: @write_permission.project.sites[0].audio_recordings[0],
                              start_time_seconds: 1,
                              end_time_seconds: 1.54,
                              low_frequency_hertz: 450.3,
                              high_frequency_hertz: 505,
                              is_reference: true,
                              creator: user_creator)

      FactoryGirl.create(:tagging, creator: user_creator, tag: lewin, audio_event: ae)
      FactoryGirl.create(:tagging, creator: user_creator, tag: koala, audio_event: ae2)
    end

    let(:ordered_audio_recordings) { [9991, 9992] }

    library_request(
        {
            description: 'LIBRARY (as reader with parameters, all filters)',
            expected_status: 200,
            expected_json_path: '0/start_time_seconds',
            document: true
        })

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