# frozen_string_literal: true

require 'webmock/rspec'

describe BawWorkers::Jobs::Analysis::Job do
  require 'support/shared_test_helpers'
  extend WebServerHelper::ExampleGroup

  include_context 'shared_test_helpers'

  # we want to control the execution of jobs for this set of tests,
  pause_all_jobs

  let(:queue_name) { Settings.actions.analysis.queue }

  let(:analysis_params) {
    {
      command_format: '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      config: 'blah',
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

  let(:analysis_query) {
    { analysis_params: }
  }

  let(:analysis_params_id) { 'analysis_job:501867ef770106f87c7f38a951bd91a6' }

  pause_all_jobs

  context 'when queuing' do
    after do
      clear_pending_jobs
    end

    it 'works on the analysis queue' do
      expect(BawWorkers::Jobs::Analysis::Job.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)
      expect_queue_count(queue_name, 1)
    end

    it 'has a sensible name' do
      job_id = BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)

      expect(job_id).not_to eq(''), 'enqueuing not successful'

      status = BawWorkers::ResqueApi.status_by_key(job_id)
      logger.info(status:)

      expected = 'Analysis for: 123456, job=20'
      expect(status.name).to eq(expected)
      expect(status).to be_queued
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect_queue_count(queue_name, 0)

      job_id1 = BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)
      expect_queue_count(queue_name, 1)
      expect(job_id1).to match(/analysis_job:[a-f0-9]{32}/)

      job_id2 = BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)
      expect_queue_count(queue_name, 1)
      expect(job_id2).to eq(job_id1)

      job_id3 = BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)
      expect_queue_count(queue_name, 1)
      expect(job_id3).to eq(job_id1)

      actual = BawWorkers::ResqueApi.peek(queue_name)
      expect(actual.arguments.first).to include(analysis_params)
      expect_queue_count(queue_name, 1)

      popped = BawWorkers::ResqueApi.pop(queue_name)
      expect(popped.arguments.first).to include(analysis_params)
      expect_queue_count(queue_name, 0)
    end

    it 'can retrieve the job' do
      expect_queue_count(queue_name, 0)

      job_id = BawWorkers::Jobs::Analysis::Job.action_enqueue(analysis_params)
      expect_queue_count(queue_name, 1)
      expect(job_id).to match(/analysis_job:[a-f0-9]{32}/)

      found = BawWorkers::ResqueApi.jobs_queued_of(BawWorkers::Jobs::Analysis::Job)
      expect(found).to have(1).items
      job = BawWorkers::ResqueApi.deserialize(found.first)

      expect(job).to be_an_instance_of(BawWorkers::Jobs::Analysis::Job)
      expect(job.queue_name).to eq queue_name
      expect(job.arguments).to match [
        a_hash_including(analysis_params)
      ]

      status = BawWorkers::ResqueApi.status_by_key(job_id)
      expect(status).to have_attributes(status: 'queued', job_id:)
    end
  end

  context 'with a web server' do
    expose_app_as_web_server
    create_audio_recordings_hierarchy

    it 'successfully runs an analysis on a file' do
      # params
      uuid = 'f7229504-76c5-4f88-90fc-b7c3f5a8732e'

      audio_recording_params =
        {
          uuid:,
          id: 123_456,
          datetime_with_offset: Time.zone.parse('2014-11-18T16:05:00Z'),
          original_format: 'ogg'
        }

      audio_recording = create(
        :audio_recording,
        :status_ready,
        creator: writer_user,
        uploader: writer_user,
        site:,
        sample_rate_hertz: 44_100,
        uuid:,
        id: 123_456,
        recorded_date: Time.zone.parse('2014-11-18T16:05:00Z'),
        media_type: 'ogg'
      )
      saved_search = Creation::Common.create_saved_search(writer_user, project, site_id: { eq: site.id })
      script = create(
        :script,
        creator: admin_user,
        executable_command: 'touch empty_file.txt; echo "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
        executable_settings: 'blah',
        analysis_action_params: {
          file_executable: './AnalysisPrograms/AnalysisPrograms.exe',
          copy_paths: [
            'empty_file.txt'
          ],
          sub_folders: []
        }
      )
      analysis_job = create(:analysis_job, creator: writer_user, script:, saved_search:,
        id: 20)
      analysis_job_item = create(:analysis_jobs_item, analysis_job:,
        audio_recording:)

      job_output_params =
        {
          uuid:,
          job_id: 20,
          sub_folders: [],
          file_name: 'empty_file.txt'
        }

      # prepare audio file
      target_file = audio_original.possible_paths(audio_recording_params)[1]
      FileUtils.mkpath(File.dirname(target_file))
      FileUtils.cp(audio_file_mono, target_file)

      # Run analysis - job enqueue done by state machine
      expect(analysis_job_item.queue!).to be true

      perform_jobs(count: 1)

      expect_jobs_to_be(completed: 1)

      # ensure the new file exists
      output_file = analysis_cache.possible_paths(job_output_params)[0]
      expect(File.exist?(output_file)).to be_truthy, output_file

      # make sure log and config are copied to correct location, and success file exists
      worker_log_file = analysis_cache.possible_paths(job_output_params.merge(file_name: BawWorkers::Jobs::Analysis::Runner::FILE_LOG))[0]
      config_file = analysis_cache.possible_paths(job_output_params.merge(file_name: BawWorkers::Jobs::Analysis::Runner::FILE_CONFIG))[0]
      success_file = analysis_cache.possible_paths(job_output_params.merge(file_name: BawWorkers::Jobs::Analysis::Runner::FILE_SUCCESS))[0]
      started_file = analysis_cache.possible_paths(job_output_params.merge(file_name: BawWorkers::Jobs::Analysis::Runner::FILE_WORKER_STARTED))[0]

      expect(File).to exist(worker_log_file)
      expect(File).to exist(config_file)
      expect(File).to exist(success_file)
      expect(File).not_to exist(started_file)
    end
  end
end
