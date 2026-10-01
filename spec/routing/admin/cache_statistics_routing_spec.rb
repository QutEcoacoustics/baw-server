# frozen_string_literal: true

describe Admin::CacheStatisticsController, type: :routing do
  describe 'routing' do
    it { expect(get('/admin/cache_statistics')).to route_to('admin/cache_statistics#index', format: 'json') }
    it { expect(get('/admin/cache_statistics/1')).to route_to('admin/cache_statistics#show', id: '1', format: 'json') }

    it {
      expect(get('/admin/cache_statistics/new')).to route_to('errors#route_error',
        requested_route: 'admin/cache_statistics/new')
    }

    it {
      expect(get('/admin/cache_statistics/1/edit')).to route_to('errors#route_error',
        requested_route: 'admin/cache_statistics/1/edit')
    }

    it_behaves_like 'our api routing patterns', '/admin/cache_statistics', 'admin/cache_statistics', [:filterable], {}
  end
end
