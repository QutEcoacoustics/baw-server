require 'spec_helper'


describe BawWorkers::Analysis::Action do
  include_context 'shared_test_helpers'

  let(:queue_name) { BawWorkers::Settings.actions.analysis.queue }

  let(:analysis_params) {
    {
        command_format: '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
        config: 'blah',
        file_executable: 'echo',
        copy_paths: [],

        uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
        id: 123456,
        datetime_with_offset: '2014-11-18T16:05:00Z',
        original_format: 'wav',

        job_id: 20,
        sub_folders: ['hello', 'here_i_am']
    }
  }

  let(:analysis_query) {
    {analysis_params: analysis_params}
  }

  let(:analysis_query_normalised) { BawWorkers::ResqueJobId.normalise(analysis_query) }

  let(:analysis_params_id) { BawWorkers::ResqueJobId.create_id_props(BawWorkers::Analysis::Action, analysis_query) }

  let(:expected_payload) {
    {
        "class" => "BawWorkers::Analysis::Action",
        "args" => [
            analysis_params_id,
            {
                "analysis_params" =>
                    {
                        "command_format" =>
                            "<{file_executable}> \"analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>\"",
                        "uuid" => "f7229504-76c5-4f88-90fc-b7c3f5a8732e",
                        "job_id" => 20,
                        "sub_folders" => ['hello', 'here_i_am'],
                        "datetime_with_offset" => "2014-11-18T16:05:00Z",
                        "original_format" => "wav",
                        "config" => "blah",
                        "id" => 123456,
                        "file_executable" => "echo",
                        "copy_paths" => []
                    }
            }
        ]
    }
  }

  context 'queues' do

    it 'works on the analysis queue' do
      expect(Resque.queue_from_class(BawWorkers::Analysis::Action)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)

      result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      result2 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(result1)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      result3 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(result1)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end

    it 'can retrieve the job' do


      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)

      result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      found = BawWorkers::ResqueApi.jobs_of_with(BawWorkers::Analysis::Action, analysis_query)

      job_id = BawWorkers::ResqueJobId.create_id_props(BawWorkers::Analysis::Action, analysis_query)
      # status = Resque::Plugins::Status::Hash.get(job_id)

      status = BawWorkers::Analysis::Action.get_job_status(analysis_params)

      expect(found.size).to eq(1)
      expect(found[0]['class']).to eq(BawWorkers::Analysis::Action.to_s)
      expect(found[0]['queue']).to eq(queue_name)
      expect(found[0]['args'].size).to eq(2)
      expect(found[0]['args'][0]).to eq(job_id)
      expect(found[0]['args'][1]).to eq(analysis_query_normalised)

      expect(job_id).to_not be_nil

      expect(status.status).to eq('queued')
      expect(status.uuid).to eq(job_id)
      expect(status.options).to eq(analysis_query_normalised)

    end

  end

  it 'successfully runs an analysis on a file' do
    # params
    uuid = 'f7229504-76c5-4f88-90fc-b7c3f5a8732e'

    audio_recording_params =
        {
            uuid: uuid,
            id: 123456,
            datetime_with_offset: Time.zone.parse('2014-11-18T16:05:00Z'),
            original_format: 'ogg'
        }

    job_output_params =
        {
            uuid: uuid,
            job_id: 20,
            sub_folders: [],
            file_name: 'empty_file.txt'
        }

    custom_analysis_params =
        {
            command_format: 'touch empty_file.txt; echo "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
            config: 'blah',
            file_executable: 'touch empty_file.txt; echo',
            copy_paths: ['empty_file.txt']
        }
            .merge(audio_recording_params)
            .merge(job_output_params)

    # prepare audio file
    target_file = audio_original.possible_paths(audio_recording_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    # prepare web requests
    # they are heavily tested in status_spec.rb so only put light restrictions here
    l = stub_request(:post, "https://localhost:3030/security").
    with(:body => "{\"email\":\"address@example.com\",\"password\":\"password\"}",
         :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})
    s1 = stub_request(:get, "https://localhost:3030/analysis_jobs/20/audio_recordings/123456").
        with(:headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})
     s2 = stub_request(:put, "https://localhost:3030/analysis_jobs/20/audio_recordings/123456").
         with(:body => "{\"status\":\"failed\"}",
              :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})
    s3 = stub_request(:put, "https://localhost:3030/analysis_jobs/20/audio_recordings/123456").
    with(:body => "{\"status\":\"working\"}",
         :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})
    s4 = stub_request(:put, "https://localhost:3030/analysis_jobs/20/audio_recordings/123456").
        with(:body => "{\"status\":\"successful\"}",
             :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})

    # Run analysis
    result = BawWorkers::Analysis::Action.action_perform(custom_analysis_params)

    # ensure the new file exists
    output_file = analysis_cache.possible_paths(job_output_params)[0]
    expect(File.exists?(output_file)).to be_truthy, output_file

    # make sure log and config are copied to correct location, and success file exists
    worker_log_file = analysis_cache.possible_paths(job_output_params.merge({file_name: BawWorkers::Analysis::Runner::FILE_LOG}))[0]
    config_file = analysis_cache.possible_paths(job_output_params.merge({file_name: BawWorkers::Analysis::Runner::FILE_CONFIG}))[0]
    success_file = analysis_cache.possible_paths(job_output_params.merge({file_name: BawWorkers::Analysis::Runner::FILE_SUCCESS}))[0]
    started_file = analysis_cache.possible_paths(job_output_params.merge({file_name: BawWorkers::Analysis::Runner::FILE_WORKER_STARTED}))[0]

    expect(File.exists?(worker_log_file)).to be_truthy
    expect(File.exists?(config_file)).to be_truthy
    expect(File.exists?(success_file)).to be_truthy
    expect(File.exists?(started_file)).to be_falsey

    # deletes the run dir when finished
    expect(Dir.exists?(result[:dir_run])).to be_falsey

  end

end