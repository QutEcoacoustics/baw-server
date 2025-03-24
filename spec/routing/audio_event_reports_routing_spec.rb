# frozen_string_literal: true

describe AudioEventReportsController, type: :routing do
  describe :routing do
    it do
      expect(get('audio_events/report')).to \
      route_to('audio_event_reports#report', format: 'json')
    end
  end
end
