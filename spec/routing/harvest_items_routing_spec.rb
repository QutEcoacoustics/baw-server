# frozen_string_literal: true

describe HarvestsController do
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

    it_behaves_like 'our api routing patterns', '/projects/1/harvests/2/items', 'harvest_items', [:filterable],
      { project_id: '1', harvest_id: '2' }

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

    it_behaves_like 'our api routing patterns', '/harvests/2/items', 'harvest_items', [:filterable], { harvest_id: '2' }
  end
end
