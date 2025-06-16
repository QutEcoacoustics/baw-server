# frozen_string_literal: true

describe ReportsController, type: :routing do
  describe :routing do
    it do
      expect(post('reports/audio_event_summary')).to \
      route_to('reports#summary', format: 'json')
    end
  end
end
