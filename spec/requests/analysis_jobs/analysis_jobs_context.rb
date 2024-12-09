# frozen_string_literal: true

RSpec.shared_context(
  'with analysis jobs context', :clean_by_truncation, :slow,
  web_server_timeout: 120
) do
  extend WebServerHelper::ExampleGroup
  include PBSHelpers

  create_audio_recordings_hierarchy

  def create_audio_recordings(count:, **args)
    created = create_list(:audio_recording, count, **args)
    link_original_audio_to_audio_recordings(created, target: Fixtures.audio_file_mono)
    created
  end

  # @!attribute [r] script_one
  #   @return [Script] the first script
  let!(:script_one) { create(:script, name: 'script_one') }

  # @!attribute [r] script_two
  #   @return [Script] the second script
  let!(:script_two) { create(:script, name: 'script_two') }

  let(:default_job_progress) {
    AnalysisJob.new.job_progress_query.transform_values { |_| 0 }.freeze
  }

  before do
    # using our helper to create them all
    audio_recording.destroy

    create_audio_recordings(count: 10, site:)
  end

  after do
    clear_original_audio
    clear_analysis_cache
  end

  pause_all_jobs
  submit_pbs_jobs_as_held
  expose_app_as_web_server

  # @param [Hash] values
  # @option values status_new_count [::Integer]
  # @option values status_queued_count [::Integer]
  # @option values status_working_count [::Integer]
  # @option values status_finished_count [::Integer]
  # @option values transition_empty_count [::Integer]
  # @option values transition_queue_count [::Integer]
  # @option values transition_cancel_count [::Integer]
  # @option values transition_retry_count [::Integer]
  # @option values transition_finish_count [::Integer]
  # @option values result_empty_count [::Integer]
  # @option values result_success_count [::Integer]
  # @option values result_failed_count [::Integer]
  # @option values result_killed_count [::Integer]
  # @option values result_cancelled_count [::Integer]
  def assert_job_progress(**values)
    values = default_job_progress.merge(values)
    job = current_job
    expect(job.job_progress_query).to match(values)
  end

  def assert_job_totals(overall_count: 0, amend_count: 0, resume_count: 0, retry_count: 0)
    job = current_job
    expect(job).to have_attributes(
      overall_count:,
      amend_count:,
      resume_count:,
      retry_count:
    )
  end

  def create_job(ongoing: false, in_project: false, scripts: nil, filter: nil, name: nil)
    scripts ||= [{ script_id: script_one.id }, { script_id: script_two.id }]
    filter ||= {}

    payload = {
      analysis_job: {
        name: name || 'test job',
        description: 'test job **description**',
        ongoing:,
        project_id: in_project ? project.id : nil,
        system_job: !in_project,
        scripts:,
        filter:
      }
    }

    token = in_project ? owner_token : admin_token

    post '/analysis_jobs', params: payload, **api_with_body_headers(token)

    expect_created
    expect_data_is_hash

    # @type [AnalysisJob]
    analysis_job = AnalysisJob.find(api_data[:id])

    expect(analysis_job).to be_present
    expect(analysis_job.analysis_jobs_scripts.count).to eq(scripts.count)
    expect(analysis_job).to be_processing
    expect(analysis_job.system_job).to eq(!in_project)
    expect(analysis_job.ongoing).to eq(ongoing)
    expect(analysis_job.project_id).to eq(in_project ? project.id : nil)

    perform_mailer_job('new_job_message')

    @analysis_job = analysis_job
  end

  # @return [AnalysisJob,nil] the current job
  def current_job
    @analysis_job&.reload
  end

  # @return [Hash]
  def fetch_job
    id = current_job.id
    get "/analysis_jobs/#{id}", **api_with_body_headers(admin_token)

    expect_success
    expect_data_is_hash
    expect_id_matches(id)

    api_data
  end

  def transition_job(transition:, token:)
    put "/analysis_jobs/#{current_job.id}/#{transition}", **api_with_body_headers(token)

    expect_success
  end

  # processes jobs in batches of 10
  # recursive!
  def process_jobs(count:, assert_progress: true)
    expect_enqueued_jobs(0)

    leftover = count > 10 ? count - 10 : 0
    count = [count, 10].min

    old_progress = current_job.job_progress_query
    BawWorkers::Jobs::Analysis::RemoteEnqueueJob.perform_later
    perform_jobs(count: 1)
    expect_pbs_jobs(count)
    release_all_held_pbs_jobs
    wait_for_pbs_jobs_to_finish(count:)
    BawWorkers::Jobs::Analysis::RemoteStatusCheckJob.perform_later
    perform_jobs(count: 1)

    # we have to do a stale check too - failed jobs will not have set the
    # transition finish value.
    BawWorkers::Jobs::Analysis::RemoteStaleCheckJob.perform_later(0)
    extra_jobs_count = 1

    # and finally, we need to perform or clear result import jobs
    # we're not testing the result import here, so we won't assert count of
    # jobs matches the count of successful results. we'll just run the right
    # number of jobs to keep the queue clear.
    import_result_jobs = BawWorkers::ResqueApi.jobs_queued_of(
      BawWorkers::Jobs::Analysis::ImportResultsJob
    )
    extra_jobs_count += import_result_jobs.size

    # there might be an email completed job in here too
    if current_job.completed?
      assert_mailer_job('completed_job_message')
      extra_jobs_count += 1
    end

    # assert there's nothing else in the queue
    expect_enqueued_jobs(extra_jobs_count)

    # after everything is enqueued, wait for the jobs to finish
    # including the stale check job
    perform_jobs(count: extra_jobs_count)

    new_progress = current_job.job_progress_query
    if assert_progress
      expect(new_progress[:status_new_count]).to eq(
        old_progress[:status_new_count] - count
      )
      expect(new_progress[:status_finished_count]).to eq(
        old_progress[:status_finished_count] + count
      )
    end

    return unless leftover.positive?

    # recurse!
    process_jobs(count: leftover, assert_progress:)
  end
end
