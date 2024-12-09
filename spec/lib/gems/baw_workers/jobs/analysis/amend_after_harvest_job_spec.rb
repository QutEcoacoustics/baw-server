# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::AmendAfterHarvestJob, :clean_by_truncation do
  create_audio_recordings_hierarchy

  # create a system job and a project job
  create_analysis_jobs_matrix(
    analysis_jobs_count: 2,
    scripts_count: 2,
    audio_recordings_count: 1
  )

  let(:system_job) { analysis_jobs_matrix[:analysis_jobs].first }
  let(:project_job) { analysis_jobs_matrix[:analysis_jobs].last }
  let(:first_script) { analysis_jobs_matrix[:scripts].first }
  let(:second_script) { analysis_jobs_matrix[:scripts].last }
  let(:harvest) { create(:harvest, project_id: project.id) }

  before do
    system_job.update!(ongoing: true, system_job: true, project_id: nil)
    project_job.update!(ongoing: true, system_job: false, project_id: project.id)
    system_job.update_column(:overall_status, :completed)
    project_job.update_column(:overall_status, :processing)
    harvest.update_column(:status, :complete)
    harvest.reload

    10.times do
      ar = create(:audio_recording, site:)
      create(:harvest_item, harvest:, audio_recording_id: ar.id)
    end
  end

  def scripts_in_jobs
    [system_job, project_job].map(&:scripts).flatten.map(&:id).uniq.count
  end

  stepwise 'when amending after harvest' do
    step 'initial assertions' do
      # two jobs, two scripts, one audio recording
      expect(AnalysisJobsItem.count).to eq(4)
      expect(AnalysisJob.count).to eq(2)
      expect(scripts_in_jobs).to eq(2)
      # one existing audio recording, one created in matrix, and
      #  10 just harvested audio recordings
      expect(AudioRecording.count).to eq(1 + 1 + 10)
    end

    step 'initial assertions for analysis jobs items' do
      expect(AnalysisJobsItem.where(analysis_job_id: system_job.id).count).to eq(2)
      expect(AnalysisJobsItem.where(analysis_job_id: project_job.id).count).to eq(2)
      expect(AnalysisJobsItem.where(script_id: first_script.id).count).to eq(2)
      expect(AnalysisJobsItem.where(script_id: second_script.id).count).to eq(2)
    end

    step 'check the amend count' do
      expect(system_job.amend_count).to eq(0)
      expect(project_job.amend_count).to eq(0)
    end

    step 'enqueue the job' do
      BawWorkers::Jobs::Analysis::AmendAfterHarvestJob.enqueue(harvest)
    end

    step 'perform the job' do
      perform_jobs(count: 1)
    end

    step 'check the job ran successfully' do
      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Analysis::AmendAfterHarvestJob)
    end

    step 'check amended assertions' do
      # two jobs, two scripts, 12 audio recordings
      # - 1 from the matrix
      # - 10 from the 'harvest'
      # - 1 from the create_audio_recordings_hierarchy
      #   This gets included in the filters because it is in the same project
      #   and the system job also includes all audio recordings.
      #   In the test setup the filters weren't evaluated, which is why it wasn't
      #   included before.
      #   This is hard to understand and i'd correct the test setup but it actually
      #   tests that things that get missed out can be included in the future - say
      #   if one of the amend operations fail.
      expect(AnalysisJobsItem.count).to eq(48)

      # everything else should remain unchanged
      expect(AnalysisJob.count).to eq(2)
      expect(scripts_in_jobs).to eq(2)
      expect(AudioRecording.count).to eq(1 + 1 + 10)
    end

    step 'check amended assertions for analysis jobs items' do
      expect(AnalysisJobsItem.where(analysis_job_id: system_job.id).count).to eq(24)
      expect(AnalysisJobsItem.where(analysis_job_id: project_job.id).count).to eq(24)
      expect(AnalysisJobsItem.where(script_id: first_script.id).count).to eq(24)
      expect(AnalysisJobsItem.where(script_id: second_script.id).count).to eq(24)
    end

    step 'check amended amend count' do
      expect(system_job.reload.amend_count).to eq(1)
      expect(project_job.reload.amend_count).to eq(1)
    end
  end
end
