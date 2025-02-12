# frozen_string_literal: true

describe BawWorkers::BatchAnalysis::Communicator, :clean_by_truncation, { web_server_timeout: 60 } do
  extend WebServerHelper::ExampleGroup
  include PBSHelpers

  create_audio_recordings_hierarchy

  let(:script_command) {
    # make the job wait so we can test state during the working phase
    <<~BASH
      touch ./wait-flag
      while test -e ./wait-flag; do
        echo "waiting for flag"
        sleep 1
      done
      cat "{config}" > "settings_result.json"
      echo 'some_binary --source "{source_dir}" --config "{config_dir}" --temp-dir "{temp_dir}" --output "{output_dir}"' > command_result.txt
      stat -c '%s' "{source}" > "result.txt"
      echo "{latitude}" >> "result.txt"
      echo "{longitude}" >> "result.txt"
      echo "{timestamp}" >> "result.txt"
      echo "{id}" >> "result.txt"
      echo "{uuid}" >> "result.txt"
    BASH
  }

  # @!attribute [r] script
  #   @return [Script]
  let!(:script) {
    create(
      :script,
      creator: admin_user,
      executable_command: script_command,
      executable_settings: 'staticsettings',
      executable_settings_name: 'settings.json',
      executable_settings_media_type: 'application/json'
    )
  }

  # @!attribute [r] analysis_job
  #   @return [AnalysisJob]
  let(:analysis_job) {
    create(
      :analysis_job,
      name: 'test_job',
      creator: writer_user
    )
  }

  # @!attribute [r] analysis_jobs_item
  #   @return [AnalysisJobsItem]
  let(:analysis_jobs_item) {
    create(
      :analysis_jobs_item,
      analysis_job:,
      audio_recording:,
      script:,
      queue_id: nil
    )
  }

  def delete_wait_flag
    path = analysis_jobs_item.results_absolute_path / 'wait-flag'
    logger.debug("deleting wait flag #{path}")
    FileUtils.rm_f(path)
  end

  before do
    AnalysisJobsScript
      .new(analysis_job:, script:, custom_settings: 'overridden settings')
      .save!

    link_original_audio_to_audio_recordings(audio_recording, target: Fixtures.audio_file_mono)
  end

  after do |_example|
    clear_original_audio
    clear_analysis_cache
  end

  pause_all_jobs
  submit_pbs_jobs_as_held
  expose_app_as_web_server

  it 'uses the correct url generation settings' do
    allow(Rails.configuration.action_mailer).to receive(:default_url_options).and_return(
      {
        host: 'banana',
        port: 6969,
        protocol: 'monkey'
      }
    )

    communicator = BawWorkers::BatchAnalysis::Communicator.new
    communicator.submit_job(analysis_jobs_item).value!

    templated_script = analysis_jobs_item.results_job_path.read

    expect(templated_script).to include('monkey://banana:6969')
  end

  # ok what are we testing here?
  #  - A job is submitted to the batch queue
  #  - The job is enqueued according to the batch queue
  #  - The model gets updated with the queue id
  #  - When it runs, finishes, or fails it updates status
  #  - When it fails it tells us why
  #
  # In the cancel test:
  #  - A job is submitted to the batch queue
  #  - It gets cancelled
  #  - the queue id is removed and the status is updated
  #
  # We're not testing:
  #  - AnalysisJob orchestration (multiple analysis job items)
  #  - AnalysisJob workflow transitions
  #  - additional jobs that are enqueued as a result of the analysis job work properly

  stepwise 'submitting a job' do
    step 'we start with no jobs' do
      expect_pbs_jobs(0)
    end

    step 'submit a job' do
      # this module is tightly integrated with the model which is not desirable
      # from a testing perspective. But the alternative is to duplicate the logic
      # in the model in this module which is also not desirable.
      analysis_jobs_item.queue!
    end

    step 'the job is in the remote queue' do
      expect_enqueued_or_held_pbs_jobs(1)
    end

    step 'the status of the model is as expected' do
      expect(analysis_jobs_item).to be_queued
      expect(analysis_jobs_item.queue_id).to be_present
      @job_id = analysis_jobs_item.queue_id
    end

    step 'we can query the remote queue for the status of the job' do
      status = BawWorkers::Config.batch_analysis.job_status(analysis_jobs_item)
      expect(status).to be_queued
    end

    step 'release the job' do
      release_all_held_pbs_jobs
    end

    step 'wait one' do
      sleep 1
    end

    step 'check the running hook has fired' do
      analysis_jobs_item.reload

      expect(analysis_jobs_item).to be_working
    end

    step 'delete the wait flag' do
      delete_wait_flag
    end

    step 'wait for the job to finish' do
      wait_for_pbs_job analysis_jobs_item.queue_id
    end

    step 'check the jobs has finished' do
      status = BawWorkers::Config.batch_analysis.job_status(analysis_jobs_item)

      expect(status).to be_finished
      expect(status).to be_successful
    end

    step 'the job finish hook has fired' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_working
      expect(analysis_jobs_item).to be_transition_finish
      expect(analysis_jobs_item.queue_id).not_to be_nil
    end

    step 'then we simulate the remote queue updating the status' do
      analysis_jobs_item.finish!
    end

    step 'the jobs status no longer exists on the remote queue' do
      result = BawWorkers::Config.batch_analysis.connection.fetch_status(@job_id)

      expect(result).to be_failure
      expect(result.failure).to match(/Unknown Job Id/)
    end

    step 'the job successful hook has fired' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_finished
      expect(analysis_jobs_item).to be_transition_empty
      expect(analysis_jobs_item).to be_result_success
      expect(analysis_jobs_item.queue_id).to be_nil
    end

    step 'the job has received a stats for the run job' do
      expect(analysis_jobs_item.used_walltime_seconds).to be >= 0
      expect(analysis_jobs_item.used_memory_bytes).to be >= 0
      expect(analysis_jobs_item.error).to be_nil
    end

    step 'the job has received settings and output them' do
      path = analysis_jobs_item.results_absolute_path
      config_output_path = path / 'settings_result.json'
      expect(config_output_path).to exist
      expect(config_output_path.read).to eq('overridden settings')
    end

    step 'the job has received a command and output it' do
      path = analysis_jobs_item.results_absolute_path
      command_output_path = path / 'command_result.txt'
      expect(command_output_path).to exist

      expect(command_output_path.read).to eq(
        %(some_binary --source "$TMPDIR/source" --config "$TMPDIR/config" --temp-dir "$TMPDIR/tmp" --output "$PBS_O_WORKDIR"\n)
      )
    end

    step 'extra metadata was templated and used' do
      path = analysis_jobs_item.results_absolute_path
      result_path = path / 'result.txt'
      expect(result_path).to exist
      result_text = result_path.read

      expect(result_text).to eq <<~TEXT
        #{Fixtures.audio_file_mono.size}
        #{audio_recording.site.latitude}
        #{audio_recording.site.longitude}
        #{audio_recording.recorded_date.iso8601}
        #{audio_recording.id}
        #{audio_recording.uuid}
      TEXT
    end

    step 'and check the job file is present' do
      job_file_path = analysis_jobs_item.results_job_path

      expect(job_file_path).to be_exist
    end

    step 'and check the job log is populated' do
      job_log_path = analysis_jobs_item.results_job_log_path
      expect(job_log_path).to be_exist
      log = job_log_path.read
      expect(log).to include('waiting for flag')

      # all the curl hooks ran successfully
      expect(log.scan('Status update: 204').size).to eq 2
    end

    step 'and there is an ImportResultsJob job waiting' do
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::ImportResultsJob)
      clear_pending_jobs
    end
  end

  stepwise 'cancelling a job' do
    step 'we start with no jobs' do
      expect_pbs_jobs(0)
    end

    step 'submit a job' do
      analysis_jobs_item.queue!
    end

    step 'the job is in the remote queue' do
      expect_enqueued_or_held_pbs_jobs(1)
    end

    step 'the status of the model is as expected' do
      expect(analysis_jobs_item).to be_queued
      expect(analysis_jobs_item.queue_id).to be_present
      @job_id = analysis_jobs_item.queue_id
    end

    step 'release the job' do
      release_all_held_pbs_jobs
    end

    step 'wait one' do
      sleep 1
    end

    step 'check the running hook has fired' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_working
      expect(analysis_jobs_item.queue_id).to be_present
    end

    step 'cancel the job' do
      analysis_jobs_item.transition_cancel!

      analysis_jobs_item.cancel!
    end

    step 'wait for the job to cancel' do
      # there should be no need for this - the job should already be gone

      wait_for_pbs_job @job_id
    end

    step 'the jobs status no longer exists on the remote queue' do
      result = BawWorkers::Config.batch_analysis.connection.fetch_status(@job_id)

      expect(result).to be_failure
      expect(result.failure).to match(/Unknown Job Id/)
    end

    step 'the job item should be cancelled' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_finished
      expect(analysis_jobs_item).to be_result_cancelled
    end

    step 'the job has received no stats for the run job' do
      # we used to get stats for cancelled jobs but it's not really useful
      # and it makes it hard to do batch cancelling
      expect(analysis_jobs_item.used_walltime_seconds).to be_nil
      expect(analysis_jobs_item.used_memory_bytes).to be_nil
      # error is only for unexpected errors - cancelling is purposeful
      expect(analysis_jobs_item.error).to be_nil
    end

    step 'and check the job log is populated' do
      job_log_path = analysis_jobs_item.results_job_log_path
      expect(job_log_path).to be_exist

      log = job_log_path.read

      expect(log).to include('waiting for flag')
      expect(log).not_to include('Success')
      expect(log).to include('cancelled')

      # only one of the curl hooks ran successfully
      expect(log.scan('Status update: 204').size).to eq 1
    end
  end

  stepwise 'a job times out' do
    before do
      # make a job that will definitely exceed the walltime and get killed
      allow(BawWorkers::Config.batch_analysis.connection).to receive(:submit_job).and_wrap_original do |original, *args, **kwargs|
        kwargs[:resources].merge!({ walltime: 1 })
        original.call(*args, **kwargs)
      end
    end

    step 'we start with no jobs' do
      expect_pbs_jobs(0)
    end

    step 'submit a job' do
      analysis_jobs_item.queue!
    end

    step 'the job change job is enqueued' do
      expect_enqueued_or_held_pbs_jobs(1)
    end

    step 'check the job resources are as expected' do
      job = BawWorkers::Config.batch_analysis.connection.fetch_status(analysis_jobs_item.queue_id).value!
      # double check our test is valid
      expect(job.resource_list.walltime).to eq 1
    end

    step 'the state of the model is as expected' do
      expect(analysis_jobs_item).to be_queued
      expect(analysis_jobs_item.queue_id).to be_present
      expect(analysis_jobs_item.work_started_at).to be_nil
    end

    step 'release the job' do
      release_all_held_pbs_jobs
    end

    step 'wait...' do
      wait_for_pbs_job analysis_jobs_item.queue_id
    end

    step 'check the running hook has fired' do
      analysis_jobs_item.reload
      # we don't check status here because hopefully the fail hook will have fired
      # after the work start hook and
      # the job item status will actually be failed
      expect(analysis_jobs_item.work_started_at).to be_within(30.seconds).of(Time.zone.now)
    end

    step 'check the job has been killed' do
      status = BawWorkers::Config.batch_analysis.job_status(analysis_jobs_item)
      expect(status).to be_finished
      expect(status).to be_killed
    end

    step 'the job error hook has fired' do
      analysis_jobs_item.reload

      expect(analysis_jobs_item).to be_working
      expect(analysis_jobs_item).to be_transition_finish
      expect(analysis_jobs_item.queue_id).not_to be_nil
    end

    step 'then we simulate the remote queue updating the status' do
      analysis_jobs_item.finish!
    end

    step 'the job item should be killed' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_finished
      expect(analysis_jobs_item).to be_transition_empty
      expect(analysis_jobs_item).to be_result_killed
      expect(analysis_jobs_item.queue_id).to be_nil
    end

    step 'the job has received a stats for the run job' do
      expect(analysis_jobs_item.used_walltime_seconds).to be >= 0
      expect(analysis_jobs_item.used_memory_bytes).to be >= 0
      expect(analysis_jobs_item.error).to eq 'job exec failed due to exceeding walltime'
    end

    step 'and check the job log is populated' do
      job_log_path = analysis_jobs_item.results_job_log_path
      expect(job_log_path).to be_exist

      log = job_log_path.read

      expect(log).to include('waiting for flag')
      expect(log).not_to include('Success')
      expect(log).to include('PBS: job killed: walltime 10 exceeded limit')

      # only two of the curl hooks ran successfully
      expect(log.scan('Status update: 204').size).to eq 2
    end
  end

  stepwise 'a job fails' do
    let(:script_command) {
      # make the job wait so we can test state during the working phase
      <<~BASH
        echo "I'm going to fail {source_dir} {output_dir}"
        cd i_do_not_exist
      BASH
    }

    before do
      # make a job that will definitely exceed the walltime and get killed
      script.executable_command = script_command
      script.save!
    end

    step 'we start with no jobs' do
      expect_pbs_jobs(0)
    end

    step 'submit a job' do
      analysis_jobs_item.queue!
    end

    step 'the job change job is enqueued' do
      expect_enqueued_or_held_pbs_jobs(1)
    end

    step 'the state of the model is as expected' do
      expect(analysis_jobs_item).to be_queued
      expect(analysis_jobs_item.queue_id).to be_present
      expect(analysis_jobs_item.work_started_at).to be_nil
    end

    step 'release the job' do
      release_all_held_pbs_jobs
    end

    step 'wait...' do
      wait_for_pbs_job analysis_jobs_item.queue_id
    end

    step 'check the running hook has fired' do
      analysis_jobs_item.reload
      # we don't check status here because hopefully the trap hook will have fired
      # after the work start hook and
      # the job item status will actually be failed
      expect(analysis_jobs_item.work_started_at).to be_within(10.seconds).of(Time.zone.now)
    end

    step 'check the job has failed' do
      status = BawWorkers::Config.batch_analysis.job_status(analysis_jobs_item)
      expect(status).to be_finished
      expect(status).to be_failed
    end

    step 'the job error hook has fired' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_working
      expect(analysis_jobs_item).to be_transition_finish
      expect(analysis_jobs_item.queue_id).not_to be_nil
    end

    step 'then we simulate the remote queue updating the status' do
      analysis_jobs_item.finish!
    end

    step 'the job item should be failed' do
      analysis_jobs_item.reload
      expect(analysis_jobs_item).to be_finished
      expect(analysis_jobs_item).to be_transition_empty
      expect(analysis_jobs_item).to be_result_failed
      expect(analysis_jobs_item.queue_id).to be_nil
    end

    step 'the job has received a stats for the run job' do
      expect(analysis_jobs_item.used_walltime_seconds).to be >= 0
      expect(analysis_jobs_item.used_memory_bytes).to be >= 0
      expect(analysis_jobs_item.error).to eq 'Script failed. Exit status 1'
    end

    step 'and check the job log is populated' do
      job_log_path = analysis_jobs_item.results_job_log_path
      expect(job_log_path).to be_exist

      log = job_log_path.read

      expect(log).to include('I\'m going to fail')
      expect(log).not_to include('Success')
      expect(log).to include('reporting error')

      # only two of the curl hooks ran successfully
      expect(log.scan('Status update: 204').size).to eq 2
    end
  end
end
