# frozen_string_literal: true

require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def test_overlap
  settings = [
    { # no overlap
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
    { # new overlaps at end of existing, adjust existing
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
    { # new overlaps at start of existing, adjust new
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
    { # new overlaps at start of existing, should not be adjusted as overlap is too much (10 sec)
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
    { # 3 recordings: overlaps at end of new recording, modify new recording
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
    { # 3 recordings: overlaps at both ends of new recording, modify new recording, and one of existing
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
    { # 3 recordings: too much overlap at one end (10 sec)
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
    },
    { # real example 1
      inputs: {
        post_item: {
          recorded_date: Time.zone.parse('2014-10-23T00:01:00+1000'),
          duration_seconds: 7200.003
        },
        existing_items: [
          {
            recorded_date: Time.zone.parse('2014-10-22T20:01:00+1000'),
            duration_seconds: 7200.003
          }
        ]
      },
      outputs: {
        status_code: 201,
        post_item: {
          recorded_date: Time.zone.parse('2014-10-23T00:01:00+1000'),
          duration_seconds: 7200.003
        },
        existing_items: [
          {
            recorded_date: Time.zone.parse('2014-10-22T20:01:00+1000'),
            duration_seconds: 7200.003
          }
        ]
      }
    }
  ]

  settings.each_with_index do |item, _index|
    post '/projects/:project_id/sites/:site_id/audio_recordings' do
      parameter :project_id, 'Requested project ID (in path/route)', required: true
      parameter :site_id, 'Requested site ID (in path/route)', required: true

      parameter :bit_rate_bps, '', scope: :audio_recording, required: true
      parameter :channels, '', scope: :audio_recording
      parameter :data_length_bytes, '', scope: :audio_recording
      parameter :duration_seconds, '', scope: :audio_recording, required: true
      parameter :file_hash, '', scope: :audio_recording, required: true
      parameter :media_type, '', scope: :audio_recording
      parameter :notes, '', scope: :audio_recording
      parameter :recorded_date, '', scope: :audio_recording
      parameter :sample_rate_hertz, '', scope: :audio_recording, required: true
      parameter :original_file_name, '', scope: :audio_recording, required: true
      parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, required: true

      # use index to know which one in settings array failed
      inputs = item[:inputs]
      outputs = item[:outputs]

      input_post_item = inputs[:post_item]

      # define item to be posted
      let(:posted_item_attrs) {
        FactoryBot.attributes_for(
          :audio_recording,
          recorded_date: input_post_item[:recorded_date],
          duration_seconds: input_post_item[:duration_seconds],
          site_id: site_id,
          status: :ready,
          creator_id: writer_user.id,
          uploader_id: writer_user.id
        )
      }

      let(:raw_post) { { audio_recording: posted_item_attrs }.to_json }

      let(:authentication_token) { harvester_token }

      status_code = outputs[:status_code]

      example "CREATE (as harvester, overlapping upload) - #{status_code}", document: true do
        # existing recordings are created here before do_request (so before the posted item)
        inputs[:existing_items].each do |existing|
          existing_item = FactoryBot.create(
            :audio_recording,
            recorded_date: existing[:recorded_date],
            duration_seconds: existing[:duration_seconds],
            site_id: site_id,
            status: :ready,
            creator: writer_user,
            uploader: writer_user
          )
          # set id so it can be used to retrieve the record
          existing[:id] = existing_item.id
        end

        do_request

        # ensure current state of audio recordings in db matches output
        case status_code
        when 201
          expect(status).to eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
          expect(response_body).to have_json_path('data/bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

          new_audio_recording_id = JSON.parse(response_body)['data']['id']
          new_recording = AudioRecording.where(id: new_audio_recording_id).first

          expected_post_item = outputs[:post_item]
          expect(new_recording.recorded_date).to eq(expected_post_item[:recorded_date])
          expect(new_recording.duration_seconds).to eq(expected_post_item[:duration_seconds])
          if expected_post_item[:modification_made]
            expect(new_recording.notes).to include('duration_adjustment_for_overlap')
          end

        when 422
          expect(status).to eq(422), "expected status 422 but was #{status}. Response body was #{response_body}"
          expect(response_body).to have_json_path('meta/error/info/overlap/count')
          expect(response_body).to have_json_path('meta/error/info/overlap/items/0/overlap_amount')

          # ensure posted audio recording does not exist
          expect(AudioRecording.where(file_hash: posted_item_attrs[:file_hash]).count)
            .to eq(0), "Input should not exist: #{posted_item_attrs}"
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

  create_entire_hierarchy

  # prepare ids needed for paths in requests below
  let(:project_id) { project.id }
  let(:site_id) { site.id }
  let(:id) { audio_recording.id }

  # Create post parameters from factory
  # make sure the uploader has write permission to the project
  let(:post_attributes) { FactoryBot.attributes_for(:audio_recording, uploader_id: writer_user.id) }

  ################################
  # LIST
  ################################
  get '/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader)', :ok, { expected_json_path: 'data/0/bit_rate_bps', data_item_count: 1 })
  end

  get '/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'LIST (as writer)', :ok, { expected_json_path: 'data/0/bit_rate_bps', data_item_count: 1 })
  end

  get '/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { 'Token token="INVALID"' }
    standard_request_options(:get, 'LIST (with invalid token)', :unauthorized, { expected_json_path: get_json_error_path(:sign_up) })
  end

  ################################
  # SHOW
  ################################
  get '/audio_recordings/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  get '/audio_recordings/:id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (as writer)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  get '/audio_recordings/:id' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { no_access_token }

    standard_request_options(:get, 'SHOW (as no access, with shallow path)', :forbidden, { expected_json_path: get_json_error_path(:permissions) })
  end

  get '/audio_recordings/:id' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader, with shallow path)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  get '/audio_recordings/:id' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (as writer, with shallow path)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  get '/audio_recordings/:id' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (as writer, with shallow path testing quoted numbers)', :ok,
                             {
                               expected_json_path: 'data/duration_seconds',
                               response_body_content: 'duration_seconds":60000.0'
                             })
  end

  ################################
  # NEW
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/new' do
    let(:authentication_token) { harvester_token }

    standard_request_options(:get, 'NEW (as harvester)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  get '/audio_recordings/new' do
    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'NEW (as reader, for api)', :ok, { expected_json_path: 'data/bit_rate_bps' })
  end

  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    parameter :bit_rate_bps, '', scope: :audio_recording, required: true
    parameter :channels, '', scope: :audio_recording
    parameter :data_length_bytes, '', scope: :audio_recording
    parameter :duration_seconds, '', scope: :audio_recording, required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :media_type, '', scope: :audio_recording
    parameter :notes, '', scope: :audio_recording
    parameter :recorded_date, '', scope: :audio_recording
    parameter :sample_rate_hertz, '', scope: :audio_recording, required: true
    parameter :original_file_name, '', scope: :audio_recording, required: true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, required: true

    let(:raw_post) { { 'audio_recording' => FactoryBot.attributes_for(:audio_recording, recorded_date: '2013-03-26 07:06:59', uploader_id: writer_user.id) }.to_json }

    let(:authentication_token) { harvester_token }

    # Execute request with ids defined in above let(:id) statements
    example 'CREATE (as harvester) - 201', document: true do
      do_request
      expect(status).to eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
      expect(response_body).to have_json_path('data/bit_rate_bps'), "could not find bit_rate_bps in #{response_body}"

      new_audio_recording_id = JSON.parse(response_body)['data']['id']

      expect(AudioRecording.where(id: new_audio_recording_id).first.status).to eq('new')
    end
  end

  # test resuming upload works
  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    parameter :bit_rate_bps, '', scope: :audio_recording, required: true
    parameter :channels, '', scope: :audio_recording
    parameter :data_length_bytes, '', scope: :audio_recording
    parameter :duration_seconds, '', scope: :audio_recording, required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :media_type, '', scope: :audio_recording
    parameter :notes, '', scope: :audio_recording
    parameter :recorded_date, '', scope: :audio_recording
    parameter :sample_rate_hertz, '', scope: :audio_recording, required: true
    parameter :original_file_name, '', scope: :audio_recording, required: true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, required: true

    file_hash = MiscHelper.new.create_sha_256_hash('c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891')
    original_file_name = 'testing.mp3'
    recorded_date = '2014-01-01 12:00:00Z'
    data_length_bytes = 9999
    media_type = 'audio/mp3'
    duration_seconds = 45.0
    notes = { 'test' => ['something'] }

    let(:ar_attributes) {
      FactoryBot.attributes_for(:audio_recording,
                                original_file_name: original_file_name,
                                file_hash: file_hash,
                                recorded_date: recorded_date,
                                data_length_bytes: data_length_bytes,
                                media_type: media_type,
                                duration_seconds: duration_seconds,
                                notes: notes,
                                site_id: site_id,
                                uploader_id: writer_user.id)
    }

    let(:raw_post) { { 'audio_recording' => ar_attributes }.to_json }

    let(:authentication_token) { harvester_token }

    # Execute request with ids defined in above let(:id) statements
    example 'CREATE (as harvester, resuming upload) - 201', document: true do
      FactoryBot.create(:audio_recording,
                        original_file_name: original_file_name,
                        file_hash: file_hash,
                        recorded_date: recorded_date,
                        data_length_bytes: data_length_bytes,
                        media_type: media_type,
                        duration_seconds: duration_seconds,
                        site_id: site_id,
                        status: :aborted)

      do_request
      expect(status).to eq(201), "expected status 201 but was #{status}. Response body was #{response_body}"
      expect(response_body).to have_json_path('data/bit_rate_bps')

      new_audio_recording_id = JSON.parse(response_body)['data']['id']

      expect(AudioRecording.where(id: new_audio_recording_id).count).to eq(1)
      expect(AudioRecording.where(id: new_audio_recording_id).first.status).to eq('new')
      expect(AudioRecording.where(id: new_audio_recording_id).first.notes).to eq(notes)
    end
  end

  # test short recordings are rejected
  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    parameter :bit_rate_bps, '', scope: :audio_recording, required: true
    parameter :channels, '', scope: :audio_recording
    parameter :data_length_bytes, '', scope: :audio_recording
    parameter :duration_seconds, '', scope: :audio_recording, required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :media_type, '', scope: :audio_recording
    parameter :notes, '', scope: :audio_recording
    parameter :recorded_date, '', scope: :audio_recording
    parameter :sample_rate_hertz, '', scope: :audio_recording, required: true
    parameter :original_file_name, '', scope: :audio_recording, required: true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, required: true

    let(:raw_post) { { 'audio_recording' => post_attributes.merge(duration_seconds: 2.0) }.to_json }

    let(:authentication_token) { harvester_token }

    standard_request_options(:post, 'CREATE (as harvester, short duration)', :unprocessable_entity,
                             {
                               expected_json_path: 'meta/error/info/duration_seconds/',
                               respond_body_content: '"Record could not be saved"'
                             })
  end

  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { { 'audio_recording' => post_attributes }.to_json }

    let(:authentication_token) { writer_token }

    standard_request_options(:post, 'CREATE (as writer)', :forbidden,
                             {
                               expected_json_path: get_json_error_path(:permissions),
                               respond_body_content: I18n.t('devise.failure.unauthorized')
                             })
  end

  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { { 'audio_recording' => post_attributes }.to_json }

    let(:authentication_token) { reader_token }

    standard_request_options(:post, 'CREATE (as reader)', :forbidden,
                             {
                               expected_json_path: get_json_error_path(:permissions),
                               respond_body_content: '"You do not have sufficient permissions to access this page."'
                             })
  end

  ################################
  # CREATE - checking overlap
  ################################

  test_overlap

  # test for 0.003 second overlap bug

  post '/projects/:project_id/sites/:site_id/audio_recordings' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true

    parameter :bit_rate_bps, '', scope: :audio_recording, required: true
    parameter :channels, '', scope: :audio_recording
    parameter :data_length_bytes, '', scope: :audio_recording
    parameter :duration_seconds, '', scope: :audio_recording, required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :media_type, '', scope: :audio_recording
    parameter :notes, '', scope: :audio_recording
    parameter :recorded_date, '', scope: :audio_recording
    parameter :sample_rate_hertz, '', scope: :audio_recording, required: true
    parameter :original_file_name, '', scope: :audio_recording, required: true
    parameter :uploader_id, 'The id of the user who uploaded the audio recording. User must have write access to the project.', scope: :audio_recording, required: true

    # define item to be posted
    let(:posted_item_attrs) {
      {
        'uploader_id' => writer_user.id,
        'recorded_date' => '2015-01-01T20:48:00.000+10:00',
        'site_id' => site_id.to_s,
        'duration_seconds' => 7200.003,
        'sample_rate_hertz' => 22_050,
        'channels' => 2,
        'bit_rate_bps' => 705_600,
        'media_type' => 'audio/wav',
        'data_length_bytes' => 635_073_024,
        'file_hash' => 'SHA256::dd27b131d947161b07f535a4eda7d9db928117c19b46124153603b299a1a1523',
        'original_file_name' => 'ABCD4_20150101_224800.wav'
      }
    }

    let(:raw_post) { { audio_recording: posted_item_attrs }.to_json }
    let(:authentication_token) { harvester_token }

    example 'CREATE AUDIORECORDING (as harvester with 0.003 overlap)', document: true do
      # create existing item
      FactoryBot.create(
        :audio_recording,
        uuid: 'aa2e4279-af2e-4603-ba0a-a9091eba727c',
        id: 262_791,
        recorded_date: '2015-01-01T22:48:00.000+10:00',
        duration_seconds: 7200.003,
        site_id: site_id,
        status: :ready,
        creator: writer_user,
        uploader: writer_user
      )

      do_request

      expect(status).to eq(201)
      expect(response_body).to include('"duration_seconds":7200.0,"')
    end
  end

  ################################
  # CHECK_UPLOADER
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { writer_user.id }
    let(:raw_post) { { 'audio_recording' => post_attributes }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request_options(:get, 'CHECK_UPLOADER (as harvester checking writer)', :no_content,
                             { expected_response_has_content: false,
                               expected_response_content_type: nil })
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { writer_user.id }
    let(:raw_post) { { 'audio_recording' => post_attributes }.to_json }

    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'CHECK_UPLOADER (as writer checking writer)', :forbidden,
                             {
                               expected_json_path: 'meta/error/info/project_id',
                               respond_body_content: ['only harvester can check uploader permissions']
                             })
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    parameter :uploader_id, 'Uploader id (in path/route)', required: true

    let(:uploader_id) { no_access_user.id }
    let(:raw_post) { { 'audio_recording' => post_attributes }.to_json }

    let(:authentication_token) { harvester_token }
    standard_request_options(:get, 'CHECK_UPLOADER (as harvester checking no access)', :forbidden,
                             {
                               expected_json_path: 'meta/error/info/user_id/',
                               respond_body_content: ['uploader does not have access to this project']
                             })
  end

  ################################
  # UPDATE_STATUS
  ################################
  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
      }.to_json
    }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE STATUS (as harvester)', :no_content,
                             { expected_response_has_content: false,
                               expected_response_content_type: nil })
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: 'blah'
      }.to_json
    }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE STATUS (as harvester incorrect file hash)', :unprocessable_entity,
                             {
                               expected_json_path: 'meta/error/info/audio_recording/file_hash/request',
                               response_body_info: 'Incorrect file hash'
                             })
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: 'blah'
      }.to_json
    }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE STATUS (as harvester incorrect uuid)', :unprocessable_entity,
                             {
                               expected_json_path: 'meta/error/info/audio_recording/uuid/stored',
                               response_body_info: 'Incorrect uuid'
                             })
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :does_not_exist
      }.to_json
    }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE STATUS (as harvester incorrect status)', :unprocessable_entity,
                             {
                               expected_json_path: 'meta/error/info/available_statuses',
                               response_body_content: '"Status does_not_exist is not in available status list"'
                             })
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
      }.to_json
    }

    let(:authentication_token) { writer_token }

    standard_request_options(:put, 'UPDATE STATUS (writer)', :forbidden,
                             {
                               expected_json_path: get_json_error_path(:permissions),
                               respond_body_content: I18n.t('devise.failure.unauthorized')
                             })
  end

  put '/audio_recordings/:id/update_status' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :file_hash, '', scope: :audio_recording, required: true
    parameter :uuid, '', scope: :audio_recording, required: true

    let(:update_status_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_status_harvester_audio_recording.id }
    let(:raw_post) {
      {
        file_hash: update_status_harvester_audio_recording.file_hash,
        uuid: update_status_harvester_audio_recording.uuid,
        status: :uploading
      }.to_json
    }

    let(:authentication_token) { reader_token }
    standard_request_options(:put, 'UPDATE STATUS (as reader)', :forbidden,
                             {
                               expected_json_path: get_json_error_path(:permissions),
                               respond_body_content: I18n.t('devise.failure.unauthorized')
                             })
  end

  ################################
  # UPDATE (for baw-workers)
  ################################

  put '/audio_recordings/:id/' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :media_type, 'media type', scope: :audio_recording, required: false
    parameter :sample_rate_hertz, 'sample rate in hertz', scope: :audio_recording, required: false
    parameter :channels, 'channel count', scope: :audio_recording, required: false
    parameter :bit_rate_bps, 'bit rate in bps', scope: :audio_recording, required: false
    parameter :data_length_bytes, 'data length of file in bytes', scope: :audio_recording, required: false
    parameter :duration_seconds, 'audio recording duration in seconds', scope: :audio_recording, required: false
    parameter :file_hash, 'audio file hash', scope: :audio_recording, required: false

    let(:update_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_harvester_audio_recording.id }

    changed_details = {
      media_type: 'audio/webm',
      sample_rate_hertz: 456,
      channels: 20,
      bit_rate_bps: 123,
      data_length_bytes: 789,
      duration_seconds: 70.0
    }

    let(:raw_post) { changed_details.to_json }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE (as harvester) standard properties', :ok,
                             { expected_json_path: 'data/duration_seconds', property_match: changed_details })
  end

  put '/audio_recordings/:id/' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :media_type, 'media type', scope: :audio_recording, required: false
    parameter :sample_rate_hertz, 'sample rate in hertz', scope: :audio_recording, required: false
    parameter :channels, 'channel count', scope: :audio_recording, required: false
    parameter :bit_rate_bps, 'bit rate in bps', scope: :audio_recording, required: false
    parameter :data_length_bytes, 'data length of file in bytes', scope: :audio_recording, required: false
    parameter :duration_seconds, 'audio recording duration in seconds', scope: :audio_recording, required: false
    parameter :file_hash, 'audio file hash', scope: :audio_recording, required: false

    let(:update_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_harvester_audio_recording.id }

    changed_details = {
      file_hash: MiscHelper.new.create_sha_256_hash
    }

    let(:raw_post) { changed_details.to_json }

    let(:authentication_token) { harvester_token }
    standard_request_options(:put, 'UPDATE (as harvester) file hash only', :ok,
                             { expected_json_path: 'data/duration_seconds' })
  end

  # fails due to file_hash and other properties in same request
  put '/audio_recordings/:id/' do
    parameter :id, 'Requested audio recording id (in path/route)', required: true
    parameter :media_type, 'media type', scope: :audio_recording, required: false
    parameter :sample_rate_hertz, 'sample rate in hertz', scope: :audio_recording, required: false
    parameter :channels, 'channel count', scope: :audio_recording, required: false
    parameter :bit_rate_bps, 'bit rate in bps', scope: :audio_recording, required: false
    parameter :data_length_bytes, 'data length of file in bytes', scope: :audio_recording, required: false
    parameter :duration_seconds, 'audio recording duration in seconds', scope: :audio_recording, required: false
    parameter :file_hash, 'audio file hash', scope: :audio_recording, required: false

    let(:update_harvester_audio_recording) { FactoryBot.create(:audio_recording) }
    let(:id) { update_harvester_audio_recording.id }

    changed_details = {
      media_type: 'audio/webm',
      sample_rate_hertz: 456,
      channels: 20,
      bit_rate_bps: 123,
      data_length_bytes: 789,
      duration_seconds: 70.0,
      file_hash: 'SHA256::something'
    }

    let(:raw_post) { changed_details.to_json }

    let(:authentication_token) { harvester_token }
    standard_request_options(
      :put,
      'UPDATE (as harvester) file hash and other properties',
      :unprocessable_entity,
      { expected_json_path: 'meta/error/info/file_hash' }
    )
  end

  # FILTER
  ###########

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            site_id: {
              less_than: 123_456
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader matching)', :ok, {
      expected_json_path: 'data/0/sample_rate_hertz',
      data_item_count: 1
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            channels: {
              lteq: 2,
              gt: 0
            },
            media_type: {
              eq: 'audio/wav'
            }
          }
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader no match)', :ok, {
      expected_json_path: 'meta/message',
      data_item_count: 0
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            site_id: {
              less_than: 123_456
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        },
        paging: {
          page: 2,
          items: 30
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader with paging)', :ok, {
      expected_json_path: 'meta/paging/page',
      data_item_count: 0,
      response_body_content: '/audio_recordings/filter?direction=desc\u0026items=30\u0026order_by=recorded_date\u0026page=1'
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            site_id: {
              less_than: 123_456
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        },
        sorting: {
          order_by: :channels,
          direction: :asc
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader with sorting)', :ok, {
      expected_json_path: 'meta/sorting/direction',
      data_item_count: 1,
      response_body_content: '/audio_recordings/filter?direction=asc\u0026items=25\u0026order_by=channels\u0026page=1'
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            site_id: {
              less_than: 123_456
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        },
        projection: {
          include: [:id, :site_id, :duration_seconds, :recorded_date, :created_at]
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader with projection)', :ok, {
      expected_json_path: 'meta/projection/include',
      data_item_count: 1,
      response_body_content: '/audio_recordings/filter?direction=desc\u0026items=25\u0026order_by=recorded_date\u0026page=1'
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      { 'paging' =>
           { 'items' => 10, 'page' => 1 },
        'projection' => {
          'include' => ['id', 'siteId', 'durationSeconds', 'recordedDate', 'createdAt']
        },
        'sorting' =>
           { 'orderBy' => 'createdAt', 'direction' => 'desc' } }
        .to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader checking camel case)', :ok, {
      expected_json_path: 'meta/projection/include',
      data_item_count: 1,
      invalid_data_content: (AudioRecording.filter_settings[:render_fields] - [:id, :site_id, :duration_seconds, :recorded_date, :created_at]).map { |i| "\"#{i}\":" },
      response_body_content: '/audio_recordings/filter?direction=desc\u0026items=10\u0026order_by=created_at\u0026page=1'
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            'projects.id' => {
              less_than: 123_456
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        },
        projection: {
          include: [:id, :site_id, :duration_seconds, :recorded_date, :created_at]
        },
        paging: {
          items: 20,
          page: 1
        },
        sorting: {
          order_by: 'created_at',
          direction: 'desc'
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader filtering by project id)', :ok, {
      response_body_content: '"projection":{"include":["id","site_id","duration_seconds","recorded_date","created_at"]},"filter":{"and":{"projects.id":{"less_than":123456},"duration_seconds":{"not_eq":40}}},"sorting":{"order_by":"created_at","direction":"desc"},"paging":{"page":1,"items":20,"total":1,"max_page":1,"current":"http://localhost:3000/audio_recordings/filter?direction=desc\u0026items=20\u0026order_by=created_at\u0026page=1"',
      data_item_count: 1
    })
  end

  post '/audio_recordings/filter' do
    let(:raw_post) {
      {
        filter: {
          and: {
            'projects.description' => {
              eq: 'test'
            },
            duration_seconds: {
              not_eq: 40
            }
          }
        },
        projection: {
          include: [:id, :site_id, :duration_seconds, :recorded_date, :created_at]
        },
        paging: {
          items: 20,
          page: 1
        },
        sorting: {
          order_by: 'created_at',
          direction: 'desc'
        }
      }.to_json
    }
    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader filtering by project image_file_name)', :bad_request, {
      response_body_content: 'Filter parameters were not valid: Name must be in [:id, :name, :description, :created_at, :creator_id], got image_file_name'
    })
  end

  post '/audio_recordings/filter' do
    let!(:new_audio_recordings) {
      Time.use_zone('Brisbane') {
        audio_recording2 = Creation::Common.create_audio_recording(reader_user, harvester_user, site)
        audio_recording2.recorded_date = Time.zone.parse('2016-03-01 11:55:00')
        audio_recording2.duration_seconds = 120
        audio_recording2.save!

        audio_recording3 = Creation::Common.create_audio_recording(reader_user, harvester_user, site)
        audio_recording3.recorded_date = Time.zone.parse('2016-03-01 13:00:00')
        audio_recording3.duration_seconds = 120
        audio_recording3.save!

        audio_recording4 = Creation::Common.create_audio_recording(reader_user, harvester_user, site)
        audio_recording4.recorded_date = Time.zone.parse('2016-03-01 11:30:00')
        audio_recording4.duration_seconds = 120
        audio_recording4.save!
      }
    }
    let(:raw_post) {
      {
        filter: {
          recorded_end_date: {
            lt: '2016-03-01T02:00:00', # in utc
            gt: '2016-03-01T01:50:00' # in utc
          }
        }
      }.to_json
    }

    let(:authentication_token) { reader_token }
    standard_request_options(:post, 'FILTER (as reader filtering by recorded_end_date)', :ok, {
      response_body_content: "\"recorded_date\":\"#{Time.use_zone('Brisbane') { Time.zone.parse('2016-03-01 11:55:00') }.in_time_zone.iso8601(3).gsub(/\s+/, '')}\"",
      data_item_count: 1
    })
  end
end
