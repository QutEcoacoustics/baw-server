# frozen_string_literal: true

describe RegionsController, type: :routing do
  describe :routing do
    it { expect(post('projects/1/regions')).to route_to('regions#create', project_id: '1', format: 'json') }
    it { expect(get('projects/1/regions/new')).to route_to('regions#new', project_id: '1', format: 'json') }
    it { expect(put('projects/1/regions/1')).to route_to('regions#update', id: '1', project_id: '1', format: 'json') }

    it {
      expect(delete('projects/1/regions/1')).to route_to('regions#destroy', id: '1', project_id: '1', format: 'json')
    }

    it { expect(get('projects/1/regions')).to route_to('regions#index', project_id: '1', format: 'json') }
    it { expect(get('projects/1/regions/1')).to route_to('regions#show', id: '1', project_id: '1', format: 'json') }

    # shallow
    it { expect(get('regions')).to route_to('regions#index', format: 'json') }
    it { expect(post('regions')).to route_to('regions#create', format: 'json') }
    it { expect(get('regions/new')).to route_to('regions#new', format: 'json') }
    it { expect(put('regions/1')).to route_to('regions#update', format: 'json', id: '1') }
    it { expect(patch('regions/1')).to route_to('regions#update', format: 'json', id: '1') }
    it { expect(delete('regions/1')).to route_to('regions#destroy', format: 'json', id: '1') }
    it { expect(post('regions/filter')).to route_to('regions#filter', format: 'json') }
  end
end
