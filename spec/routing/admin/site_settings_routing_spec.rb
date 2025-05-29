# frozen_string_literal: true

describe Admin::SiteSettingsController, type: :routing do
  describe 'routing' do
    it { expect(get('/admin/site_settings')).to route_to('admin/site_settings#index', format: 'json') }

    it {
      expect(get('/admin/site_settings/new')).to route_to('errors#route_error',
        requested_route: 'admin/site_settings/new')
    }

    it {
      expect(get('/admin/site_settings/1/edit')).to route_to('errors#route_error',
        requested_route: 'admin/site_settings/1/edit')
    }

    it { expect(get('/admin/site_settings/1')).to route_to('admin/site_settings#show', id: '1', format: 'json') }
    it { expect(post('/admin/site_settings')).to route_to('admin/site_settings#create', format: 'json') }
    it { expect(put('/admin/site_settings/1')).to route_to('admin/site_settings#update', id: '1', format: 'json') }
    it { expect(patch('/admin/site_settings/1')).to route_to('admin/site_settings#update', id: '1', format: 'json') }
    it { expect(delete('/admin/site_settings/1')).to route_to('admin/site_settings#destroy', id: '1', format: 'json') }

    # accepts setting name as an id
    it {
      expect(get('/admin/site_settings/setting_name')).to route_to('admin/site_settings#show', id: 'setting_name',
        format: 'json')
    }

    it {
      expect(put('/admin/site_settings/setting_name')).to route_to('admin/site_settings#update', id: 'setting_name',
        format: 'json')
    }

    it {
      expect(patch('/admin/site_settings/setting_name')).to route_to('admin/site_settings#update', id: 'setting_name',
        format: 'json')
    }

    it {
      expect(delete('/admin/site_settings/setting_name')).to route_to('admin/site_settings#destroy', id: 'setting_name',
        format: 'json')
    }

    it_behaves_like 'our api routing patterns', '/admin/site_settings', 'admin/site_settings', [:upsertable], {}
  end
end
