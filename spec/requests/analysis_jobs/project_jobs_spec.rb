# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs', :clean_by_truncation do
  include_context 'with analysis jobs context'

  describe 'project jobs' do
    it 'can create a project job' do
      job = create_job(in_project: true)

      expect(job.project_id).to be_present
      expect(job.project).not_to be_nil
      expect(job).not_to be_system_job
    end

    # this test seems a little obvious but it is the mirror of the same test
    # in the system_jobs_spec.rb file
    it 'will scope the filter to the set project and reject recordings from any other project' do
      # should have an entirely separate graph of relationships
      isolated_audio_recording = create(:audio_recording)
      expect(isolated_audio_recording.site.region.project.id).not_to eq project.id

      # default filter covers all audio recordings we have access too - which
      # for admin is everything
      job = create_job(in_project: true)

      # 11 recordings, ignoring 1 not in project, 2 scripts = 20 job items
      expect(job.analysis_jobs_items.count).to eq(10 * 2)
      expect(job.analysis_jobs_items.map(&:audio_recording_id)).not_to include(isolated_audio_recording.id)
    end
  end
end
