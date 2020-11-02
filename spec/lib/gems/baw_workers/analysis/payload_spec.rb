# frozen_string_literal: true

require 'workers_helper'

# test payload splitting with partial payload method
describe BawWorkers::Analysis::Payload do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  let(:payload) {
    BawWorkers::Analysis::Payload.new(BawWorkers::Config.logger_worker)
  }

  let(:analysis_params) {
    {
      command_format: '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      config: 'blah a very long and repeated blob of text' * 300,
      file_executable: 'echo',
      copy_paths: [],

      uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
      id: 123_456,
      datetime_with_offset: '2014-11-18T16:05:00Z',
      original_format: 'wav',

      job_id: 20,
      sub_folders: ['hello', 'here_i_am']
    }
  }

  let(:analysis_params2) {
    {
      command_format: '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      config: 'blah a very long and repeated blob of text' * 300,
      file_executable: 'echo',
      copy_paths: [],

      uuid: '146d4563-18e7-4aea-ab46-bce5c69dc68c',
      id: 654_321,
      datetime_with_offset: '2014-11-19T16:05:00Z',
      original_format: 'wav',

      job_id: 20,
      sub_folders: ['hello', 'here_i_am']
    }
  }

  let(:expected_payload) {
    {
      'class' => 'BawWorkers::Analysis::Action',
      'args' => [
        '7f3600c1257e4a334f759d9f4de2629e',
        {
          'analysis_params' =>
              {
                'payload_base' => 'baw-workers:partial_payload:analysis:20-1471651200',
                'uuid' => 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
                'id' => 123_456,
                'datetime_with_offset' => '2014-11-18T16:05:00Z',
                'original_format' => 'wav',
                'job_id' => 20
              }
        }
      ]
    }
  }

  let(:expected_payload2) {
    {
      'class' => 'BawWorkers::Analysis::Action',
      'args' => [
        '9bbcedbfa382f507a8f9209500dd4486',
        {
          'analysis_params' =>
              {
                'payload_base' => 'baw-workers:partial_payload:analysis:20-1471651200',
                'uuid' => '146d4563-18e7-4aea-ab46-bce5c69dc68c',
                'id' => 654_321,
                'datetime_with_offset' => '2014-11-19T16:05:00Z',
                'original_format' => 'wav',
                'job_id' => 20
              }
        }
      ]
    }
  }

  let(:partial_payload) {
    {

      'command_format' =>
          '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      'sub_folders' => ['hello', 'here_i_am'],
      'config' => 'blah a very long and repeated blob of text' * 300,
      'file_executable' => 'echo',
      'copy_paths' => []

    }
  }

  before(:each) do
    default_queue = Settings.actions.analysis.queue

    allow(Settings.actions.analysis).to receive(:queue).and_return(default_queue + '_manual_tick')

    # cleanup resque queues before each test
    BawWorkers::ResqueApi.clear_queue(default_queue)
    BawWorkers::ResqueApi.clear_queue(Settings.actions.analysis.queue)
    BawWorkers::ResqueApi.clear_queue('failed')
    BawWorkers::PartialPayload.delete_all
  end

  let(:queue_name) { Settings.actions.analysis.queue }

  it 'stores and retrieves partial payloads' do
    # set up
    expect(Resque.size(queue_name)).to eq(0)

    # enqueue two jobs... we expect two small payloads and one partial payload
    group_key = Date.new(2016, 8, 20).to_time.to_i.to_s
    result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params, group_key)
    result2 = BawWorkers::Analysis::Action.action_enqueue(analysis_params2, group_key)
    expect(Resque.size(queue_name)).to eq(2)
    expect(result1).to be_a(String)
    expect(result2).to be_a(String)
    expect(result1.size).to eq(32)
    expect(result2.size).to eq(32)

    found1 = BawWorkers::ResqueApi.jobs_of_with(
      BawWorkers::Analysis::Action,
      expected_payload['args'][1]
    )
    found2 = BawWorkers::ResqueApi.jobs_of_with(
      BawWorkers::Analysis::Action,
      expected_payload2['args'][1]
    )

    expect(found1.size).to eq(1)
    expect(found2.size).to eq(1)
    expect(found1[0]['class']).to eq(BawWorkers::Analysis::Action.to_s)
    expect(found2[0]['class']).to eq(BawWorkers::Analysis::Action.to_s)
    expect(found1[0]['queue']).to eq(queue_name)
    expect(found2[0]['queue']).to eq(queue_name)
    expect(found1[0]['args'].size).to eq(2)
    expect(found2[0]['args'].size).to eq(2)
    expect(found1[0]['args'][1]).to eq(expected_payload['args'][1])
    expect(found2[0]['args'][1]).to eq(expected_payload2['args'][1])

    # ensure the partial payload exists and is correct
    result = BawWorkers::PartialPayload.get('analysis:20-' + group_key)
    expect(result).to_not be_nil
    expect(result).to eq(partial_payload)

    # ensure entire payload is reconstituted by the time it gets to `action_perform`
    expect(BawWorkers::Analysis::Action).to receive(:action_perform).with(analysis_params.stringify_keys)

    # prepare audio file
    target_file = audio_original.possible_paths(
      uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
      id: 123_456,
      datetime_with_offset: Time.zone.parse('"2014-11-18T16:05:00Z'),
      original_format: 'wav'
    )[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    # dequeue and run a job
    was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Analysis::Action.queue)

    expect(was_run).to eq(true)
  end
end
