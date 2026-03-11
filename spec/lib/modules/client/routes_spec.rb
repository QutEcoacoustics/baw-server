# frozen_string_literal: true

describe Client::Routes do
  let(:client_routes) { Client::Routes.new(host: 'ecosounds.org', port: nil, protocol: 'http') }

  describe '#analysis_job_url' do
    let(:analysis_job) { create(:analysis_job) }

    context 'when the analysis job belongs to a project' do
      it 'returns the /projects/ URL' do
        url = client_routes.analysis_job_url(analysis_job)
        expect(url.to_s).to eq("http://ecosounds.org/projects/#{analysis_job.project.id}/analysis_jobs/#{analysis_job.id}")
      end
    end

    context 'when the analysis job is a system job' do
      it 'returns the /admin/ URL' do
        analysis_job.project_id = nil
        url = client_routes.analysis_job_url(analysis_job)
        expect(url.to_s).to eq("http://ecosounds.org/admin/analysis_jobs/#{analysis_job.id}")
      end
    end
  end
end
