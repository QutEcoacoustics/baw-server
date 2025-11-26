# frozen_string_literal: true

RSpec.describe AudioEvents::GroupByController, type: :routing do
  describe 'routing' do
    it {
      expect(get('/audio_events/group_by/sites')).to(
        route_to('audio_events/group_by#group_audio_events_by_sites', format: 'json')
      )
    }

    it {
      expect(post('/audio_events/group_by/sites')).to(
        route_to('audio_events/group_by#group_audio_events_by_sites', format: 'json')
      )
    }
  end
end
