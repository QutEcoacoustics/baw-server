require 'spec_helper'

describe SitesController, :type => :routing do
  describe :routing do

    it { expect(get('projects/1/sites/1/upload_instructions')).to route_to('sites#upload_instructions', id: '1', project_id: '1') }
    it { expect(get('projects/1/sites/1/harvest')).to route_to('sites#harvest', id: '1', project_id: '1') }
    it { expect(get('projects/1/sites/1/harvest.yml')).to route_to('sites#harvest', id: '1', project_id: '1', format: 'yml') }

    it { expect(post('projects/1/sites')).to route_to('sites#create', project_id: '1') }
    it { expect(get('projects/1/sites/new')).to route_to('sites#new', project_id: '1') }
    it { expect(get('projects/1/sites/1/edit')).to route_to('sites#edit', id: '1', project_id: '1') }

    it { expect(put('projects/1/sites/1')).to route_to('sites#update', id: '1', project_id: '1') }
    it { expect(delete('projects/1/sites/1')).to route_to('sites#destroy', id: '1', project_id: '1') }

    # used by client
    it { expect(get('projects/1/sites')).to route_to('sites#index', project_id: '1', format: 'json') }
    it { expect(get('sites/1')).to route_to('sites#show_shallow', id: '1', format: 'json') }
    it { expect(get('projects/1/sites/1')).to route_to('sites#show', id: '1', project_id: '1') }

    it { expect(get('sites/filter')).to route_to('sites#filter', format: 'json') }
    it { expect(post('sites/filter')).to route_to('sites#filter', format: 'json') }

  end
end