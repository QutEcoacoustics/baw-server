require 'spec_helper'

describe TaggingsController do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#index', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(post('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#create', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/new')).to route_to('taggings#new', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5/edit')).to route_to('taggings#edit', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#show', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(put('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#update', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(delete('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#destroy', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }

    it { expect(get('/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#index', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(post('/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#create', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/new')).to route_to('taggings#new', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/5/edit')).to route_to('taggings#edit', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#show', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(put('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#update', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(delete('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#destroy', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }

    it { expect(get('/taggings/user/1/tags')).to route_to('taggings#user_index', user_id: '1', format: 'json')}

  end
end
