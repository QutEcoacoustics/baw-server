require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def test_overlap

  settings = [
      {# no overlap
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-01 12:00:00Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-01 12:01:00Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 201,
           post_item: {
               recorded_date: Time.zone.parse('2000-01-01 12:00:00Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-01 12:01:00Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      },
      {# new overlaps at end of existing, adjust existing
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-02 12:00:59Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-02 12:00:00Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 201,
           post_item: {
               recorded_date: Time.zone.parse('2000-01-02 12:00:59Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-02 12:00:00Z'),
                   duration_seconds: 59.0
               }
           ]
       }
      },
      {# new overlaps at start of existing, adjust new
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-03 12:00:00Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-03 12:00:59Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 201,
           post_item: {
               recorded_date: Time.zone.parse('2000-01-03 12:00:00Z'),
               duration_seconds: 59.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-03 12:00:59Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      },
      {# new overlaps at start of existing, should not be adjusted as overlap is too much
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-04 12:00:00Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-04 12:00:50Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 422,
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-04 12:00:50Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      },
      {# 3 recordings: overlaps at end of new recording, modify new recording
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-05 12:01:02Z'),
               duration_seconds: 60.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-05 12:00:00Z'),
                   duration_seconds: 60.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-05 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 201,
           post_item: {
               recorded_date: Time.zone.parse('2000-01-05 12:01:02Z'),
               duration_seconds: 58.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-05 12:00:00Z'),
                   duration_seconds: 60.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-05 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      },
      {# 3 recordings: overlaps at both ends of new recording, modify new recording, and one of existing
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-06 12:00:59Z'),
               duration_seconds: 62.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-06 12:00:00Z'),
                   duration_seconds: 60.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-06 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 201,
           post_item: {
               recorded_date: Time.zone.parse('2000-01-06 12:00:59Z'),
               duration_seconds: 61.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-06 12:00:00Z'),
                   duration_seconds: 59.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-06 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      },
      {# 3 recordings: too much overlap at one end
       inputs: {
           post_item: {
               recorded_date: Time.zone.parse('2000-01-07 12:00:50Z'),
               duration_seconds: 70.0
           },
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-07 12:00:00Z'),
                   duration_seconds: 60.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-07 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       },
       outputs: {
           status_code: 422,
           existing_items: [
               {
                   recorded_date: Time.zone.parse('2000-01-07 12:00:00Z'),
                   duration_seconds: 60.0
               },
               {
                   recorded_date: Time.zone.parse('2000-01-07 12:02:00Z'),
                   duration_seconds: 60.0
               }
           ]
       }
      }
  ]

  settings.each_with_index do |item, index|

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
      parameter :original_file_name, '', scope: :audio_recording, :required => true
      parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, :required => true

      # use index to know which one in settings array failed
      inputs = item[:inputs]
      outputs = item[:outputs]

      input_post_item = inputs[:post_item]

      # define item to be posted
      let(:posted_item_attrs) { FactoryGirl.attributes_for(
          :audio_recording,
          recorded_date: input_post_item[:recorded_date],
          duration_seconds: input_post_item[:duration_seconds],
          site_id: site_id,
          status: :ready,
          creator_id: @write_permission.user.id,
          uploader_id: @write_permission.user.id) }

      let(:raw_post) { {audio_recording: posted_item_attrs}.to_json }

      let(:authentication_token) { harvester_token }

      status_code = outputs[:status_code]

      example "CREATE (as harvester, overlapping upload) - #{status_code}", document: true do

        # existing recordings are created here before do_request (so before the posted item)
        inputs[:existing_items].each do |existing|
          existing_item = FactoryGirl.create(
              :audio_recording,
              recorded_date: existing[:recorded_date],
              duration_seconds: existing[:duration_seconds],
              site_id: site_id,
              status: :ready,
              creator: @write_permission.user,
              uploader: @write_permission.user)
          # set id so it can be used to retrieve the record
          existing[:id] = existing_item.id
        end


        do_request

        # ensure current state of audio recordings in db matches output
        if status_code == 201
          status.should eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
          response_body.should have_json_path('bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

          new_audio_recording_id = JSON.parse(response_body)['id']
          new_recording = AudioRecording.where(id: new_audio_recording_id).first

          expected_post_item = outputs[:post_item]
          expect(new_recording.recorded_date).to eq(expected_post_item[:recorded_date])
          expect(new_recording.duration_seconds).to eq(expected_post_item[:duration_seconds])
          expect(new_recording.notes).to include('duration_adjustment_for_overlap') if expected_post_item[:modification_made]

        elsif status_code == 422
          status.should eq(422), "expected status 422 but was #{status}. Response body was #{response_body}"
          response_body.should have_json_path('recorded_date/0/problem'), "could not find 'problem' in #{response_body}"
          response_body.should have_json_path('recorded_date/0/overlapping_audio_recordings/0/overlap_amount'), "could not find 'overlap_amount' in #{response_body}"

          # ensure posted audio recording does not exist
          expect(AudioRecording.where(file_hash: posted_item_attrs[:file_hash]).count)
          .to eq(0), "all file_hashes #{AudioRecording.select(:file_hash).all}, input posted #{posted_item_attrs[:file_hash]}"
        else
          raise "unknown status code #{status_code}"
        end

        # check that existing audio recordings match expected
        outputs[:existing_items].each_with_index do |expected, expected_index|
          stored_id = inputs[:existing_items][expected_index][:id]
          existing_recording = AudioRecording.where(id: stored_id).first

          expect(existing_recording.recorded_date).to eq(expected[:recorded_date])
          expect(existing_recording.duration_seconds).to eq(expected[:duration_seconds])
          expect(existing_recording.notes).to include('duration_adjustment_for_overlap') if expected[:modification_made]
        end

      end
    end
  end
end

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
  let(:post_attributes) { FactoryGirl.attributes_for(:audio_recording, uploader_id: @write_permission.user.id) }

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
    parameter :original_file_name, '', scope: :audio_recording, :required => true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, :required => true

    let(:raw_post) { {'audio_recording' => FactoryGirl.attributes_for(:audio_recording, recorded_date: '2013-03-26 07:06:59', uploader_id: @write_permission.user.id)}.to_json }

    let(:authentication_token) { harvester_token }

    # Execute request with ids defined in above let(:id) statements
    example 'CREATE (as harvester) - 201', document: true do
      do_request
      status.should eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
      response_body.should have_json_path('bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

      new_audio_recording_id = JSON.parse(response_body)['id']

      AudioRecording.where(id: new_audio_recording_id).first.status.should eq('new')
    end

  end

  # test resuming upload works
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
    parameter :original_file_name, '', scope: :audio_recording, :required => true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, :required => true

    file_hash = "SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891"
    original_file_name = 'testing.mp3'
    recorded_date = '2014-01-01 12:00:00Z'
    data_length_bytes = 9999
    media_type = 'audio/mp3'
    duration_seconds = 45.0

    let(:ar_attributes) { FactoryGirl.attributes_for(:audio_recording,
                                                     original_file_name: original_file_name,
                                                     file_hash: file_hash,
                                                     recorded_date: recorded_date,
                                                     data_length_bytes: data_length_bytes,
                                                     media_type: media_type,
                                                     duration_seconds: duration_seconds,
                                                     site_id: site_id,
                                                     status: :new,
                                                     uploader_id: @write_permission.user.id) }

    let(:raw_post) { {'audio_recording' => ar_attributes}.to_json }

    let(:authentication_token) { harvester_token }

    # Execute request with ids defined in above let(:id) statements
    example 'CREATE (as harvester, resuming upload) - 201', document: true do

      FactoryGirl.create(:audio_recording,
                         original_file_name: original_file_name,
                         file_hash: file_hash,
                         recorded_date: recorded_date,
                         data_length_bytes: data_length_bytes,
                         media_type: media_type,
                         duration_seconds: duration_seconds,
                         site_id: site_id,
                         status: :aborted)

      do_request
      status.should eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
      response_body.should have_json_path('bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

      new_audio_recording_id = JSON.parse(response_body)['id']

      AudioRecording.where(id: new_audio_recording_id).count.should eq(1)
      AudioRecording.where(id: new_audio_recording_id).first.status.should eq('new')
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
  # CREATE - checking overlap
  ################################

  test_overlap

  ################################
  # CHECK_UPLOADER
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @write_permission.user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('CHECK_UPLOADER (as harvester checking writer)', 204, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @write_permission.user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }
    standard_request('CHECK_UPLOADER (as writer checking writer)', 403, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { @user.id }
    let(:raw_post) { {'audio_recording' => post_attributes}.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('CHECK_UPLOADER (as harvester checking no access)', 200, nil, true, 'uploader does not have access to this project')
  end

  ################################
  # UPDATE_STATUS
  ################################
  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
    }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester)', 204, nil, true)
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: 'blah'
    }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester incorrect file hash)', 422, nil, true, 'Incorrect file hash')
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: 'blah',
    }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester incorrect uuid)', 422, nil, true, 'Incorrect uuid')
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :does_not_exist
    }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request('UPDATE STATUS (as harvester incorrect status)', 422, nil, true, 'is not in available status list')
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
    }.to_json }

    let(:authentication_token) { writer_token }

    standard_request('UPDATE STATUS (writer)', 403, nil, true, I18n.t('devise.failure.unauthorized'))

  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, :required => true
    parameter :uuid, '', scope: :audio_recording, :required => true

    let(:update_status_harvester_audio_recording) { FactoryGirl.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) { {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
    }.to_json }

    let(:authentication_token) { reader_token }
    standard_request('UPDATE STATUS (as reader)', 403, nil, true, I18n.t('devise.failure.unauthorized'))

  end


end