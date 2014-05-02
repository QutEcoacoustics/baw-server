require 'spec_helper'

describe TagsController do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/tags')).to route_to('tags#index', project_id: '1', site_id: '2', audio_recording_id: '3', audio_event_id: '4', format: 'json') }
    it { expect(get('audio_recordings/3/audio_events/4/tags')).to route_to('tags#index', audio_recording_id: '3', audio_event_id: '4', format: 'json') }

    it { expect(get('/tags')).to route_to('tags#index', format: 'json') }
    it { expect(post('/tags')).to route_to('tags#create', format: 'json') }
    it { expect(get('/tags/new')).to route_to('tags#new', format: 'json') }
    it { expect(get('/tags/1/edit')).to route_to('errors#routing', requested_route: 'tags/1/edit') }
    it { expect(get('/tags/1')).to route_to('tags#show', id: '1', format: 'json') }
    it { expect(put('/tags/1')).to route_to('errors#routing', requested_route: 'tags/1') }
    it { expect(delete('/tags/1')).to route_to('errors#routing', requested_route: 'tags/1') }

    it { expect(get('/tags?filter=koala,bellow')).to route_to('tags#index', format: 'json')}
  end
end