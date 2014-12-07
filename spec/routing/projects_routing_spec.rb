require 'spec_helper'

describe ProjectsController, :type => :routing do
  describe :routing do

    it { expect(post('/projects/1/update_permissions')).to route_to('projects#update_permissions', id: '1') }
    it { expect(get('/projects/new_access_request')).to route_to('projects#new_access_request') }
    it { expect(post('/projects/submit_access_request')).to route_to('projects#submit_access_request') }

    it { expect(get('/projects')).to route_to('projects#index') }
    it { expect(post('/projects')).to route_to('projects#create') }
    it { expect(get('/projects/new')).to route_to('projects#new') }
    it { expect(get('/projects/1/edit')).to route_to('projects#edit', id: '1') }
    it { expect(get('/projects/1')).to route_to('projects#show', id: '1') }
    it { expect(put('/projects/1')).to route_to('projects#update', id: '1') }
    it { expect(delete('/projects/1')).to route_to('projects#destroy', id: '1') }

  end
end