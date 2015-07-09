require 'spec_helper'

describe AnalysisJobsController, :type => :routing do
  describe :routing do

    it { expect(get('/projects/1/datasets/2/jobs/3')).to route_to('jobs#show', project_id: '1', dataset_id: '2', id: '3') }
    it { expect(get('/projects/1/datasets/2/jobs')).to route_to('jobs#index', project_id: '1', dataset_id: '2', format: 'json') }

    it { expect(post('/projects/1/jobs')).to route_to('jobs#create', project_id: '1') }
    it { expect(get('/projects/1/jobs/new')).to route_to('jobs#new', project_id: '1') }
    it { expect(get('/projects/1/jobs/3/edit')).to route_to('jobs#edit', project_id: '1', id: '3') }
    it { expect(put('/projects/1/jobs/3')).to route_to('jobs#update', project_id: '1', id: '3') }
    it { expect(delete('/projects/1/jobs/3')).to route_to('jobs#destroy', project_id: '1', id: '3') }

    it { expect(get('/projects/1/jobs')).to route_to('jobs#index', project_id: '1', format: 'json') }

  end
end