require 'spec_helper'

describe DatasetsController do
  describe :routing do

    it { expect(post('/projects/1/datasets')).to route_to('datasets#create', project_id: '1') }
    it { expect(get('/projects/1/datasets/new')).to route_to('datasets#new', project_id: '1') }
    it { expect(get('/projects/1/datasets/2/edit')).to route_to('datasets#edit', project_id: '1', id: '2') }
    it { expect(get('/projects/1/datasets/2')).to route_to('datasets#show', project_id: '1', id: '2') }
    it { expect(put('/projects/1/datasets/2')).to route_to('datasets#update', project_id: '1', id: '2') }
    it { expect(delete('/projects/1/datasets/2')).to route_to('datasets#destroy', project_id: '1', id: '2') }

    it { expect(get('/projects/1/datasets')).to route_to('datasets#index', project_id: '1', format: 'json') }

  end
end
