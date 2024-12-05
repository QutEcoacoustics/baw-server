# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  stepwise 'amendment' do
    step 'create an amendable job' do
      create_job(ongoing: true)
    end

    step 'we have 20 job items' do
      assert_job_progress(
        status_new_count: 20,
        transition_queue_count: 20,
        result_empty_count: 20
      )
    end

    step 'create some new recordings' do
      create_audio_recordings(count: 2)
    end

    step 'now we have 12 recordings but job items are unchanged' do
      expect(AudioRecording.count).to eq 12
      expect(current_job.analysis_jobs_items.count).to eq 20
    end

    step 'now amend the job (before it starts)' do
      transition_job(transition: :amend, token: admin_token)
    end

    step 'and we should have 24 job items' do
      # 2 scripts, 2 new recordings, =4 additional job items
      assert_job_progress(
        status_new_count: 24,
        transition_queue_count: 24,
        result_empty_count: 24
      )

      expect(current_job.amend_count).to eq 1
    end

    step 'process some jobs' do
      process_jobs(count: 10)
    end

    step 'and we should have 14 remaining job items' do
      assert_job_progress(
        status_new_count: 14,
        status_finished_count: 10,
        transition_queue_count: 14,
        transition_empty_count: 10,
        result_empty_count: 14,
        result_success_count: 10
      )
    end

    step 'create some more recordings' do
      create_audio_recordings(count: 2)
    end

    step 'and ammend the job (part way through)' do
      transition_job(transition: :amend, token: admin_token)
    end

    step 'and we should have 18 remaining job items' do
      assert_job_progress(
        status_new_count: 18,
        status_finished_count: 10,
        transition_queue_count: 18,
        transition_empty_count: 10,
        result_empty_count: 18,
        result_success_count: 10
      )

      expect(current_job.amend_count).to eq 2
    end

    step 'process the remaining jobs' do
      process_jobs(count: 18)
    end

    step 'and everything should be completed' do
      expect(current_job).to be_completed
      assert_job_progress(
        status_new_count: 0,
        status_finished_count: 28,
        transition_empty_count: 28,
        result_empty_count: 0,
        result_success_count: 28
      )
    end

    step 'create some more recordings (after finish)' do
      create_audio_recordings(count: 2)
    end

    step 'now amend the job (after it has finished)' do
      transition_job(transition: :amend, token: admin_token)
    end

    step 'this should "re-open" the job' do
      expect(current_job).to be_processing
    end

    step 'and we should have two new job items' do
      assert_job_progress(
        status_new_count: 4,
        status_finished_count: 28,
        transition_queue_count: 4,
        transition_empty_count: 28,
        result_empty_count: 4,
        result_success_count: 28
      )

      expect(current_job.amend_count).to eq 3
    end

    step 'process the remaining jobs' do
      process_jobs(count: 4)
    end

    step 'and everything should be completed' do
      expect(current_job).to be_completed
      assert_job_progress(
        status_new_count: 0,
        status_finished_count: 32,
        transition_empty_count: 32,
        result_empty_count: 0,
        result_success_count: 32
      )
    end
  end
end
