require 'spec_helper'

describe AudioEventsController do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/download')).to route_to('audio_events#download', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'csv') }

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events')).to route_to('audio_events#index', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'json') }
    it { expect(post('/projects/1/sites/2/audio_recordings/3/audio_events')).to route_to('audio_events#create', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/new')).to route_to('audio_events#new', project_id: '1', site_id: '2', audio_recording_id: '3', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/edit')).to route_to('audio_events#edit', project_id: '1', site_id: '2', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('audio_events#show', project_id: '1', site_id: '2', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(put('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('audio_events#update', project_id: '1', site_id: '2', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(delete('/projects/1/sites/2/audio_recordings/3/audio_events/4')).to route_to('audio_events#destroy', project_id: '1', site_id: '2', audio_recording_id: '3', id: '4', format: 'json') }

    it { expect(get('/audio_recordings/3/audio_events/download')).to route_to('audio_events#download', audio_recording_id: '3', format: 'csv') }

    it { expect(get('/audio_recordings/3/audio_events')).to route_to('audio_events#index', audio_recording_id: '3', format: 'json') }
    it { expect(post('/audio_recordings/3/audio_events')).to route_to('audio_events#create', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/new')).to route_to('audio_events#new', audio_recording_id: '3', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/edit')).to route_to('audio_events#edit', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4')).to route_to('audio_events#show', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(put('/audio_recordings/3/audio_events/4')).to route_to('audio_events#update', audio_recording_id: '3', id: '4', format: 'json') }
    it { expect(delete('/audio_recordings/3/audio_events/4')).to route_to('audio_events#destroy', audio_recording_id: '3', id: '4', format: 'json') }

    it { expect(get('/audio_events/library')).to route_to('audio_events#library', format: 'json') }
    it { expect(get('/audio_events/new')).to route_to('audio_events#new', format: 'json') }

  end
end
