require 'spec_helper'

describe ScriptsController do
  describe :routing do

    it { expect(get('/scripts/1/versions')).to route_to('scripts#versions', id: '1') }
    it { expect(get('/scripts/1/versions/1')).to route_to('scripts#version', id: '1', version_id: '1') }
    it { expect(post('/scripts/1')).to route_to('scripts#update', id: '1') }
    it { expect(get('/scripts')).to route_to('scripts#index') }
    it { expect(post('/scripts')).to route_to('scripts#create') }
    it { expect(get('/scripts/new')).to route_to('scripts#new') }
    it { expect(get('/scripts/1/edit')).to route_to('scripts#edit', id: '1') }
    it { expect(get('/scripts/1')).to route_to('scripts#show', id: '1') }

  end
end
