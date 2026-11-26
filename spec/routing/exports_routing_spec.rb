# frozen_string_literal: true

RSpec.describe ExportsController, type: :routing do
  describe 'routing' do
    it { expect(get('/exports')).to route_to('exports#index', format: 'json') }
    it { expect(post('/exports')).to route_to('exports#create', format: 'json') }
    it { expect(get('/exports/new')).to route_to('exports#new', format: 'json') }
    it { expect(get('/exports/1')).to route_to('exports#show', id: '1', format: 'json') }
    it { expect(delete('/exports/1')).to route_to('exports#destroy', id: '1', format: 'json') }

    it { expect(get('/exports/1/edit')).to route_to('errors#route_error', requested_route: 'exports/1/edit') }
    it { expect(put('/exports/1')).to route_to('errors#route_error', requested_route: 'exports/1') }
    it { expect(patch('/exports/1')).to route_to('errors#route_error', requested_route: 'exports/1') }

    it { expect(get('/exports/1/download')).to route_to('exports#download', id: '1', format: 'json') }

    it_behaves_like 'our api routing patterns', '/exports', 'exports', [:filterable]
  end
end
