# frozen_string_literal: true



describe ScriptsController, type: :routing do
  describe :routing do
    it { expect(post('/admin/scripts/1')).to route_to('admin/scripts#update', id: '1') }
    it { expect(get('/admin/scripts')).to route_to('admin/scripts#index') }
    it { expect(post('/admin/scripts')).to route_to('admin/scripts#create') }
    it { expect(get('/admin/scripts/new')).to route_to('admin/scripts#new') }
    it { expect(get('/admin/scripts/1/edit')).to route_to('admin/scripts#edit', id: '1') }
    it { expect(get('/admin/scripts/1')).to route_to('admin/scripts#show', id: '1') }

    it { expect(get('/scripts')).to route_to('scripts#index', format: 'json') }
    it { expect(get('/scripts/filter')).to route_to('scripts#filter', format: 'json') }
    it { expect(post('/scripts/filter')).to route_to('scripts#filter', format: 'json') }
    it { expect(get('/scripts/1')).to route_to('scripts#show', id: '1', format: 'json') }
  end
end
