# frozen_string_literal: true

describe BawWorkers::BatchAnalysis::Communicator do
  create_audio_recordings_hierarchy

  let!(:script) {
    create(
      :script,
      creator: admin_user,
      executable_command:
        'echo  "some_binary" --source "{source}" --config "{config}" --temp-dir "{temp}" --output "{output}"',
      executable_settings: 'staticsettings',
      executable_settings_name: 'settings.json',
      executable_settings_media_type: 'application/json',
      analysis_action_params: nil
    )
  }

  let(:analysis_job) {
    create(
      :analysis_job,
      name: 'test_job',
      creator: writer_user,
      script:,
      saved_search: nil
    )
  }

  let(:analysis_job_item) {
    create(
      :analysis_jobs_item,
      analysis_job:,
      audio_recording:,
      queue_id: nil,
      status: 'new'
    )
  }

  before do
    [audio_recording].each do |r|
      link_original_audio(
        target: Fixtures.audio_file_mono,
        uuid: r.uuid,
        datetime_with_offset: r.recorded_date,
        original_format: r.media_type
      )
    end
  end

  after(:all) do
    clear_original_audio
    clear_analysis_cache
  end

  pause_all_jobs

  stepwise 'submitting a job' do
    step 'submit a job' do
      BawWorkers::Config.batch_analysis.submit_job(
        analysis_job_item
      )
    end

    step 'the job change job is enqueued' do
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::AnalysisChangeJob)
      expect_pbs_jobs(0)
    end

    step 'the job script'

    step 'run the job state change' do
      perform_jobs(1)
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
    end

    step 'and now we should have pbs jobs enqueued' do
      expect_enqueued_pbs_jobs(1)
    end
  end

  describe 'cancelling a job' do
  end
end
