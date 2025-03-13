# frozen_string_literal: true

describe VerificationsController, type: :routing do
  describe :routing do
    # nested routes
    # index
    it do
      expect(get('audio_recordings/3/audio_events/4/verifications')).to \
      route_to('verifications#index', audio_recording_id: '3',
        audio_event_id: '4', format: 'json')
    end

    it do
      expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/verifications')).to \
      route_to('errors#route_error',
        requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/verifications')
    end

    # show
    it do
      expect(get('audio_recordings/3/audio_events/4/verifications/1')).to \
      route_to('verifications#show', audio_recording_id: '3',
        audio_event_id: '4', id: '1', format: 'json')
    end

    it do
      expect(get('audio_events/4/verifications/1')).to \
      route_to('errors#route_error', requested_route: 'audio_events/4/verifications/1')
    end

    # filter
    it do
      expect(get('audio_recordings/1/audio_events/1/verifications/?filter=skip')).to \
      route_to('verifications#index', audio_recording_id: '1',
        audio_event_id: '1', format: 'json', filter: 'skip')
    end

    it do
      expect(get('audio_recordings/1/verifications/?filter=skip')).to \
      route_to('errors#route_error', filter: 'skip', requested_route: 'audio_recordings/1/verifications')
    end

    # shallow routes
    # index
    it { expect(get('/verifications')).to route_to('verifications#index', format: 'json') }

    # show
    it { expect(get('verifications/1')).to route_to('verifications#show', id: '1', format: 'json') }

    # create
    it { expect(post('/verifications')).to route_to('verifications#create', format: 'json') }

    # update
    it { expect(put('/verifications/1')).to route_to('verifications#update', id: '1', format: 'json') }
    it { expect(patch('/verifications/1')).to route_to('verifications#update', id: '1', format: 'json') }

    # destroy
    it { expect(delete('/verifications/1')).to route_to('verifications#destroy', id: '1', format: 'json') }

    # filter
    it do
      expect(get('/verifications?filter=unsure')).to \
      route_to('verifications#index', format: 'json', filter: 'unsure')
    end

    # negative cases
    it { expect(post('/verifications/1')).to route_to('errors#route_error', requested_route: 'verifications/1') }
    it { expect(delete('/verifications')).to route_to('errors#route_error', requested_route: 'verifications') }

    it_behaves_like 'our api routing patterns', '/verifications', 'verifications', [:filterable, :upsertable]
  end
end
