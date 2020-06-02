# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::Harvest::Action do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:queue_name) { BawWorkers::Settings.actions.harvest.queue }

  before(:each) do
    BawWorkers::ResqueApi.clear_queue(queue_name)
  end

  let(:folder_example) { File.expand_path File.join(File.dirname(__FILE__), 'folder_example.yml') }

  let(:test_harvest_request_params) {
    {
      file_path: '/path1/path2/TEST_20140731_100956.wav',
      file_name: 'TEST_20140731_100956.wav',
      extension: 'wav',
      access_time: '2014-12-02T19:41:55.862+00:00',
      change_time: '2014-12-02T19:41:55.906+00:00',
      modified_time: '2014-12-02T19:41:55.906+00:00',
      data_length_bytes: 498_220,
      project_id: 1020,
      site_id: 1109,
      uploader_id: 138,
      utc_offset: '+10',
      raw: {
        prefix: 'TEST_',
        year: '2014',
        month: '07',
        day: '31',
        hour: '10',
        min: '09',
        sec: '56',
        ext: 'wav'
      },
      recorded_date: '2014-07-31T10:09:56.000+10:00',
      prefix: 'TEST'
    }
  }
  let(:expected_payload) {
    {
      'class' => 'BawWorkers::Harvest::Action',
      'args' => [
        'c32a6e87d0563574c11971714f2c6f06',
        'harvest_params' => test_harvest_request_params.stringify_keys
      ]
    }
  }

  it 'works on the harvest queue' do
    expect(Resque.queue_from_class(BawWorkers::Harvest::Action)).to eq(queue_name)
  end

  it 'can enqueue' do
    result = BawWorkers::Harvest::Action.action_enqueue(test_harvest_request_params)
    expect(Resque.size(queue_name)).to eq(1)

    actual = Resque.peek(queue_name)
    expect(actual.to_json.to_s).to eq(expected_payload.to_json.to_s)
  end

  it 'has a sensible name' do
    allow_any_instance_of(BawWorkers::Harvest::SingleFile).to receive(:run).and_return(['/tmp/a_fake_file_mock'])

    unique_key = BawWorkers::Harvest::Action.action_enqueue(test_harvest_request_params)

    was_run = emulate_resque_worker(BawWorkers::Harvest::Action.queue)
    status = BawWorkers::ResqueApi.status_by_key(unique_key)

    expected = 'Harvest for: TEST_20140731_100956.wav, data_length_bytes=498220, site_id=1109'
    expect(status.name).to eq(expected)
  end

  it 'can enqueue from rake using resque in dry run' do
    result = BawWorkers::Harvest::Action.action_enqueue_rake(harvest_to_do_path, false)
  end

  it 'can enqueue from rake using resque in real run' do
    result = BawWorkers::Harvest::Action.action_enqueue_rake(harvest_to_do_path, true)
  end

  it 'can perform from rake using resque in dry run' do
    result = BawWorkers::Harvest::Action.action_perform_rake(harvest_to_do_path, false)
  end

  it 'can perform from rake using resque in real run' do
    endpoint_login = default_uri + BawWorkers::Settings.endpoints.login
    email = 'address@example.com'
    auth_token = 'auth_token_string'
    request_headers_base = { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
    stub_login = stub_request(:post, endpoint_login)
                 .with(
                   body: get_api_security_request(email, 'password'),
                   headers: request_headers_base
                 )
                 .to_return(status: 200, body: get_api_security_response(email, auth_token).to_json, headers: {})

    file_hash = 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891'
    recorded_date = '2014-10-10T10:10:10.000+10:00'
    request_headers = request_headers_base.merge('Authorization' => "Token token=\"#{auth_token}\"")
    request_create_body = {
      uploader_id: 30,
      recorded_date: recorded_date,
      site_id: 20,
      duration_seconds: 70.0,
      sample_rate_hertz: 44_100,
      channels: 1,
      bit_rate_bps: 239_920,
      media_type: 'audio/ogg',
      data_length_bytes: 822_281,
      file_hash: file_hash,
      original_file_name: 'test_20141010_101010.ogg',
      notes: {
        relative_path: 'harvest_file_exists/test_20141010_101010.ogg',
        sensor_type: 'SM2',
        information: [
          'stripped left channel due to bad mic',
          'appears to have electronic interference from solar panel'
        ]
      }
    }
    response_create_body = {
      meta: {
        status: 422,
        message: 'Unprocessable Entity',
        error: {
          details: 'Record could not be saved',
          info: {
            duration_seconds:
                  ['must be greater than or equal to 10']
          }
        }
      },
      data: nil
    }
    uuid = 'fb4af424-04c1-4739-96e3-23f8dc719665'
    request_update_status_body = {
      uuid: uuid,
      file_hash: file_hash,
      status: nil
    }

    stub_uploader_check =
      stub_request(:get, "#{default_uri}/projects/10/sites/20/audio_recordings/check_uploader/30")
      .with(headers: request_headers)
      .to_return(status: 204)

    stub_create =
      stub_request(:post, "#{default_uri}/projects/10/sites/20/audio_recordings")
      .with(body: request_create_body.to_json, headers: request_headers)
      .to_return(status: 201, body: response_create_body.to_json)

    stub_uploading_status =
      stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
      .with(body: request_update_status_body.merge(status: 'uploading'), headers: request_headers)
      .to_return(status: 200)

    stub_ready_status =
      stub_request(:put, "#{default_uri}/audio_recordings/177/update_status")
      .with(body: request_update_status_body.merge(status: 'ready'), headers: request_headers)
      .to_return(status: 200)

    result = BawWorkers::Harvest::Action.action_perform_rake(harvest_to_do_path, true)

    # verify - requests made in the correct order
    # stub_login.should have_been_made.once
    # stub_uploader_check.should have_been_made.once
    # stub_create.should have_been_made.once
    # stub_uploading_status.should have_been_made.once
    # stub_ready_status.should have_been_made.once
  end

end
