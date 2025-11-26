# frozen_string_literal: true

RSpec.describe Sites::GroupByController, type: :routing do
  describe 'routing' do
    it {
      expect(get('/sites/group_by/audio_events')).to(
        route_to('sites/group_by#group_sites_by_audio_events', format: 'json')
      )
    }

    it {
      expect(post('/sites/group_by/audio_events')).to(
        route_to('sites/group_by#group_sites_by_audio_events', format: 'json')
      )
    }
  end
end
