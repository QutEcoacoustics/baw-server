# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::Analysis::Status do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  # we want to control the execution of jobs for this set of tests,
  # so change the queue name so the test worker does not
  # automatically process the jobs
  before(:each) do
    default_queue = BawWorkers::Settings.actions.analysis.queue

    allow(BawWorkers::Settings.actions.analysis).to receive(:queue).and_return(default_queue + '_manual_tick')

    # cleanup resque queues before each test
    BawWorkers::ResqueApi.clear_queue(default_queue)
    BawWorkers::ResqueApi.clear_queue(BawWorkers::Settings.actions.analysis.queue)

  end

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

  def prepare_audio_file
    target_file = audio_original.possible_paths(
      uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
      id: 123_456,
      datetime_with_offset: Time.zone.parse('"2014-11-18T16:05:00Z'),
      original_format: 'wav'
    )[0]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)
  end

  def stub_status_get(status)
    body = <<-JSON
      {
          "meta": {
              "status": 200,
              "message": "OK"
          },
          "data": {
              "id": 999999,
              "analysis_job_id": 20,
              "audio_recording_id": 123456,
              "queue_id": "0f4c5f8547349e8cfd2e5eb7b7014c46",
              "status": "#{status}",
              "created_at": "2016-09-05T05:36:22.242+02:00",
              "queued_at": "2016-09-05T05:36:22.338+02:00",
              "work_started_at": null,
              "completed_at": null
          }
      }
    JSON

    stub_request(:get, "#{default_uri}/analysis_jobs/20/audio_recordings/123456")
      .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                       'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: body)
  end

  def stub_status_put(new_status, failCount = 0)
    body = <<-JSON
      {
          "meta": {
              "status": 200,
              "message": "OK"
          },
          "data": {
              "id": 999999,
              "analysis_job_id": 20,
              "audio_recording_id": 123456,
              "queue_id": "0f4c5f8547349e8cfd2e5eb7b7014c46",
              "status": "#{new_status}",
              "created_at": "2016-09-05T05:36:22.242+02:00",
              "queued_at": "2016-09-05T05:36:22.338+02:00",
              "work_started_at": null,
              "completed_at": null
          }
      }
    JSON

    s = stub_request(:put, "#{default_uri}/analysis_jobs/20/audio_recordings/123456")
        .with(headers: { 'Accept' => 'application/json', 'Authorization' => 'Token token="auth_token_string"',
                         'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' },
              body: { status: new_status }.to_json)

    s = s.to_timeout.times(failCount) if failCount > 0
    s = s.then.to_return(status: 200, body: body)

    s
  end

  def stub_login
    stub_request(:post, default_uri + BawWorkers::Settings.endpoints.login)
      .with(body: get_api_security_request('address@example.com', 'password'))
      .to_return(body: get_api_security_response('address@example.com', 'auth_token_string').to_json)
  end

  it 'sets the website status to :successful if it just works' do
    queue_name = BawWorkers::Settings.actions.analysis.queue

    # set up
    expect(Resque.size(queue_name)).to eq(0)

    # enqueue
    _ = BawWorkers::Analysis::Action.action_enqueue(analysis_params)

    expect(Resque.size(queue_name)).to eq(1)

    # prepare
    prepare_audio_file
    l = stub_login
    s1 = stub_status_get(:queued)
    s2 = stub_status_put(:working)
    s3 = stub_status_put(:successful)

    expect_requests_made_in_order(l, s1, s2, s3) do
      # dequeue and run a job
      was_run = emulate_resque_worker(BawWorkers::Analysis::Action.queue)

      expect(was_run).to eq(true)
    end
  end

  it 'sets the website status to :timed_out if it times out' do
    queue_name = BawWorkers::Settings.actions.analysis.queue

    # set up
    expect(Resque.size(queue_name)).to eq(0)

    # override the timeout value
    allow(BawWorkers::Analysis::Runner).to receive(:timeout_seconds).and_return(0.05)
    # and insert a sleep into the command to run
    analysis_params_modified = analysis_params.dup
    analysis_params_modified[:command_format] = 'sleep 5 && <{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"'

    # enqueue
    _ = BawWorkers::Analysis::Action.action_enqueue(analysis_params_modified)

    expect(Resque.size(queue_name)).to eq(1)

    # prepare
    prepare_audio_file
    l = stub_login
    s1 = stub_status_get(:queued)
    s2 = stub_status_put(:working)
    s3 = stub_status_put(:timed_out)

    expect_requests_made_in_order(l, s1, s2, s3) do
      # dequeue and run a job
      expect {
        _ = emulate_resque_worker(BawWorkers::Analysis::Action.queue)
      }.to raise_error(BawAudioTools::Exceptions::AudioToolTimedOutError)
    end
  end

  it 'sets the website status to :failed if the job fails' do
    queue_name = BawWorkers::Settings.actions.analysis.queue

    # set up
    expect(Resque.size(queue_name)).to eq(0)
    # and insert error output into the command to run
    analysis_params_modified = analysis_params.dup
    analysis_params_modified[:command_format] = '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>" >&2 && (exit 1)'

    # enqueue
    result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params_modified)

    expect(Resque.size(queue_name)).to eq(1)

    # prepare
    prepare_audio_file
    l = stub_login
    s1 = stub_status_get(:queued)
    s2 = stub_status_put(:working)
    s3 = stub_status_put(:failed)

    expect_requests_made_in_order(l, s1, s2, s3) do
      # dequeue and run a job
      expect {
        was_run = emulate_resque_worker(BawWorkers::Analysis::Action.queue)
      }.to raise_error(BawAudioTools::Exceptions::AudioToolError)
    end
  end

  it 'sets the website status to :cancelled if the job was killed by the website' do
    queue_name = BawWorkers::Settings.actions.analysis.queue

    # set up
    expect(Resque.size(queue_name)).to eq(0)
    # and insert error output into the command to run

    # enqueue
    result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)

    expect(Resque.size(queue_name)).to eq(1)

    # prepare
    prepare_audio_file
    l = stub_login
    s1 = stub_status_get(:cancelling)
    s2 = stub_status_put(:cancelled)

    expect_requests_made_in_order(l, s1, s2) do
      # dequeue and run a job
      was_run = emulate_resque_worker(BawWorkers::Analysis::Action.queue)
      expect(was_run).to eq(true)
    end
  end

  it 'tries multiple times to set the website, and sends an email if it cant' do
    queue_name = BawWorkers::Settings.actions.analysis.queue

    # set up
    expect(Resque.size(queue_name)).to eq(0)
    ActionMailer::Base.deliveries.clear

    # enqueue
    result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)

    expect(Resque.size(queue_name)).to eq(1)

    # prepare
    prepare_audio_file
    l = stub_login
    s1 = stub_status_get(:queued)
    s2 = stub_status_put(:working)
    s3 = stub_status_put(:successful, 3)

    expect_requests_made_in_order(l, s1, s2) do
      # dequeue and run a job
      was_run = false
      time = Benchmark.realtime {
        was_run = emulate_resque_worker(BawWorkers::Analysis::Action.queue)
      }

      expect(was_run).to eq(true)
      expect(time).to be_within(1.0).of(27 + 1.2)
    end

    expect(s3).to have_been_made.times(4)

    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end

end
