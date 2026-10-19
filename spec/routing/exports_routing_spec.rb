# frozen_string_literal: true

RSpec.describe ExportsController, type: :routing do
  describe 'routing' do
    it { expect(post('/exports')).to route_to('exports#create', format: 'json') }
    it { expect(get('/exports/1/download')).to route_to('exports#download', id: '1', format: 'json') }
  end
end
