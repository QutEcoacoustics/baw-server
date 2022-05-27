# frozen_string_literal: true

describe HarvestsController, type: :routing do
  describe 'routing' do
    it { expect(post('projects/1/harvests')).to route_to('harvests#create', project_id: '1', format: 'json') }
    it { expect(get('projects/1/harvests/new')).to route_to('harvests#new', project_id: '1', format: 'json') }
    it { expect(put('projects/1/harvests/1')).to route_to('harvests#update', id: '1', project_id: '1', format: 'json') }

    it {
      expect(delete('projects/1/harvests/1')).to route_to('harvests#destroy', id: '1', project_id: '1', format: 'json')
    }

    it { expect(get('projects/1/harvests')).to route_to('harvests#index', project_id: '1', format: 'json') }
    it { expect(get('projects/1/harvests/1')).to route_to('harvests#show', id: '1', project_id: '1', format: 'json') }

    # shallow
    it { expect(get('harvests')).to route_to('harvests#index', format: 'json') }
    it { expect(post('harvests')).to route_to('harvests#create', format: 'json') }
    it { expect(get('harvests/new')).to route_to('harvests#new', format: 'json') }
    it { expect(put('harvests/1')).to route_to('harvests#update', format: 'json', id: '1') }
    it { expect(patch('harvests/1')).to route_to('harvests#update', format: 'json', id: '1') }
    it { expect(delete('harvests/1')).to route_to('harvests#destroy', format: 'json', id: '1') }
    it { expect(post('harvests/filter')).to route_to('harvests#filter', format: 'json') }
  end
end
