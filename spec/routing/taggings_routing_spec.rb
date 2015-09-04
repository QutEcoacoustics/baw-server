require 'spec_helper'

describe TaggingsController, :type => :routing do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings') }
    it { expect(post('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/new')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/new') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5/edit')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5/edit') }
    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5') }
    it { expect(put('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5') }
    it { expect(delete('/projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/taggings/5') }


    it { expect(post('/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#create', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/new')).to route_to('taggings#new', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/5/edit')).to route_to('errors#route_error', requested_route: 'audio_recordings/3/audio_events/4/taggings/5/edit') }
    it { expect(put('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#update', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
    it { expect(delete('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#destroy', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }

    it { expect(get('/user_accounts/1/taggings')).to route_to('taggings#user_index', user_id: '1', format: 'json') }

    # used by client
    it { expect(get('/audio_recordings/3/audio_events/4/taggings')).to route_to('taggings#index', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('/audio_recordings/3/audio_events/4/taggings/5')).to route_to('taggings#show', audio_recording_id: '3', audio_event_id: '4', id: '5', format: 'json') }
  end
end