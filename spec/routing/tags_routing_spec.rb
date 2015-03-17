require 'spec_helper'

describe TagsController, :type => :routing do
  describe :routing do

    it { expect(get('/projects/1/sites/2/audio_recordings/3/audio_events/4/tags')).to route_to('errors#route_error', requested_route: 'projects/1/sites/2/audio_recordings/3/audio_events/4/tags') }
    it { expect(get('audio_recordings/3/audio_events/4/tags')).to route_to('tags#index', audio_recording_id: '3', audio_event_id: '4', format: 'json') }

    it { expect(post('/tags')).to route_to('tags#create', format: 'json') }
    it { expect(get('/tags/new')).to route_to('tags#new', format: 'json') }
    it { expect(get('/tags/1/edit')).to route_to('errors#route_error', requested_route: 'tags/1/edit') }

    it { expect(put('/tags/1')).to route_to('errors#route_error', requested_route: 'tags/1') }
    it { expect(delete('/tags/1')).to route_to('errors#route_error', requested_route: 'tags/1') }

    it { expect(get('/tags?filter=koala,bellow')).to route_to('tags#index', format: 'json', filter: 'koala,bellow')}

    # used by client
    it { expect(get('/tags')).to route_to('tags#index', format: 'json') }
    it { expect(get('/tags/1')).to route_to('tags#show', id: '1', format: 'json') }

    it { expect(get('/tags/filter')).to route_to('tags#filter', format: 'json') }
    it { expect(post('/tags/filter')).to route_to('tags#filter', format: 'json') }

  end
end