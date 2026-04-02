# frozen_string_literal: true

RSpec.describe ReportsController, type: :routing do
  describe 'routing' do
    it {
      expect(post('/reports/tag_accumulation')).to(
        route_to('reports#tag_accumulation', format: 'json')
      )
    }

    it {
      expect(post('/reports/tag_frequency')).to(
        route_to('reports#tag_frequency', format: 'json')
      )
    }
  end
end
