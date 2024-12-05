# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  describe 'system jobs' do
    it 'can create a system job as an admin' do
      job = create_job(in_project: false)

      expect(job.system_job).to be_truthy
      expect(job.project).to be_nil
    end

    it 'the `system` route parameter always resolves to the latest system job' do
      job = create_job(in_project: false)

      get('/analysis_jobs/system', **api_with_body_headers(admin_token))
      expect_success
      expect_id_matches(job.id)

      job2 = create_job(in_project: false, name: 'second job')

      expect(job2.id).not_to eq(job.id)

      get('/analysis_jobs/system', **api_with_body_headers(admin_token))
      expect_success
      expect_id_matches(job2.id)
    end

    it 'can add recordings from any project' do
      # should have an entirely separate graph of relationships
      isolated_audio_recording = create(:audio_recording)
      expect(isolated_audio_recording.site.region.project.id).not_to eq project.id

      # default filter covers all audio recordings we have access too - which
      # for admin is everything
      job = create_job(in_project: false)

      # 10 recordings, plus 1 new one, 2 scripts = 22 job items
      expect(job.analysis_jobs_items.count).to eq((10 + 1) * 2)
      expect(job.analysis_jobs_items.map(&:audio_recording_id)).to include(isolated_audio_recording.id)
    end
  end
end
