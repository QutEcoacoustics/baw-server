# frozen_string_literal: true

describe HarvestsController, type: :routing do
  describe 'routing' do
    it {
      expect(get('projects/1/harvests/2/items/a/b/c')).to route_to(
        'harvest_items#index',
        project_id: '1',
        harvest_id: '2',
        path: 'a/b/c',
        format: 'json'
      )
    }

    it {
      expect(get('projects/1/harvests/2/items')).to route_to(
        'harvest_items#index',
        project_id: '1',
        harvest_id: '2',
        #path: '',
        format: 'json'
      )
    }

    it {
      expect(get('projects/1/harvests/2/items/filter')).to route_to(
        'harvest_items#filter',
        project_id: '1',
        harvest_id: '2',
        format: 'json'
      )
    }

    it {
      expect(post('projects/1/harvests/2/items/filter')).to route_to(
        'harvest_items#filter',
        project_id: '1',
        harvest_id: '2',
        format: 'json'
      )
    }

    # shallow
    it {
      expect(get('harvests/2/items/a/b/c')).to route_to(
        'harvest_items#index',
        harvest_id: '2',
        path: 'a/b/c',
        format: 'json'
      )
    }

    it {
      expect(get('harvests/2/items')).to route_to(
        'harvest_items#index',
        harvest_id: '2',
        #path: '',
        format: 'json'
      )
    }

    it {
      expect(get('harvests/2/items/filter')).to route_to(
        'harvest_items#filter',
        harvest_id: '2',
        format: 'json'
      )
    }

    it {
      expect(post('harvests/2/items/filter')).to route_to(
        'harvest_items#filter',
        harvest_id: '2',
        format: 'json'
      )
    }
  end
end
