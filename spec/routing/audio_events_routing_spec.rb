# frozen_string_literal: true



describe AudioEventsController, type: :routing do
  describe :routing do
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events') }
    it { expect(post('/projects/1/sites/2/audio_recordings/3/audio_events')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/new')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/new') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/edit')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/edit') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4') }
    it { expect(put('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4') }
    it { expect(delete('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4') }

    it { expect(post('/audio_recordings/3/audio_events')).to route_to('audio_events#create', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/new')).to route_to('audio_events#new', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/edit')).to route_to('errors#route_error', requested_route: 'audio_recordings/3/audio_events/4/edit') }
    it { expect(put('/audio_recordings/3/audio_events/4')).to route_to('audio_events#update', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(delete('/audio_recordings/3/audio_events/4')).to route_to('audio_events#destroy', audio_recording_id: '3', id: '4', format: 'json') }

    it { expect(get('/audio_events/new')).to route_to('errors#route_error', requested_route: 'audio_events/new') }

    it { expect(get('/projects/1/audio_events/download')).to route_to('audio_events#download', project_id: '1', format: 'csv') }
    it { expect(get('/projects/1/regions/2/audio_events/download')).to route_to('audio_events#download', project_id: '1', region_id: '2', format: 'csv') }
    it { expect(get('/projects/1/sites/2/audio_events/download')).to route_to('audio_events#download', project_id: '1', site_id: '2', format: 'csv') }

    it { expect(get('/user_accounts/1/audio_events/download')).to route_to('audio_events#download', user_id: '1', format: 'csv') }
    it { expect(get('/user_accounts/1/audio_events/download.csv')).to route_to('audio_events#download', user_id: '1', format: 'csv') }

    # used by client
    it { expect(get('/audio_recordings/3/audio_events')).to route_to('audio_events#index', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4')).to route_to('audio_events#show', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/download')).to route_to('audio_events#download', audio_recording_id: '3', format: 'csv') }
    it { expect(get('/audio_recordings/3/audio_events/download.csv')).to route_to('audio_events#download', audio_recording_id: '3', format: 'csv') }

    it { expect(get('/audio_events/library')).to route_to('errors#route_error', requested_route: 'audio_events/library') }
    it { expect(get('/audio_events/library/paged')).to route_to('errors#route_error', requested_route: 'audio_events/library/paged') }

    it_behaves_like 'our api routing patterns', '/audio_events', 'audio_events', [:filterable]
  end
end
