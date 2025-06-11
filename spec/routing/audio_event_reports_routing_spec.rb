# frozen_string_literal: true

describe AudioEventReportsController, type: :routing do
  describe :routing do
    it do
      expect(post('audio_event_reports')).to \
      route_to('audio_event_reports#filter', format: 'json')
    end
  end
end
