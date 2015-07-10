require 'spec_helper'

describe AnalysisJobsController, :type => :routing do
  describe :routing do

    it { expect(get('/analysis_jobs/3')).to route_to('analysis_jobs#show', id: '3', format: 'json') }
    it { expect(get('/analysis_jobs')).to route_to('analysis_jobs#index', format: 'json') }

    it { expect(post('/analysis_jobs')).to route_to('analysis_jobs#create', format: 'json') }
    it { expect(get('/analysis_jobs/new')).to route_to('analysis_jobs#new', format: 'json') }
    it { expect(get('/analysis_jobs/3/edit')).to route_to('errors#route_error', requested_route: 'analysis_jobs/3/edit') }
    it { expect(put('/analysis_jobs/3')).to route_to('analysis_jobs#update', id: '3', format: 'json') }
    it { expect(delete('/analysis_jobs/3')).to route_to('analysis_jobs#destroy', id: '3', format: 'json') }

    it { expect(get('/analysis_jobs')).to route_to('analysis_jobs#index', format: 'json') }

  end
end