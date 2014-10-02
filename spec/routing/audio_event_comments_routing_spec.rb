require 'spec_helper'

describe AudioEventCommentsController do
    describe :routing do

      it { expect(get('/user_accounts/1/audio_event_comments')).to route_to('user_accounts#audio_event_comments', id: '1') }

      it { expect(get('/audio_events/1/comments')).to route_to('audio_event_comments#index', audio_event_id: '1', format: 'json') }
      it { expect(post('/audio_events/1/comments')).to route_to('audio_event_comments#create', audio_event_id: '1', format: 'json') }
      it { expect(get('/audio_events/1/comments/new')).to route_to('audio_event_comments#new', audio_event_id: '1', format: 'json') }

      it { expect(get('/audio_events/1/comments/2/edit')).to route_to('errors#route_error', requested_route: 'audio_events/1/comments/2/edit') }

      it { expect(get('/audio_events/1/comments/2')).to route_to('audio_event_comments#show', audio_event_id: '1', id: '2', format: 'json') }
      it { expect(put('/audio_events/1/comments/2')).to route_to('audio_event_comments#update', audio_event_id: '1', id: '2', format: 'json') }
      it { expect(delete('/audio_events/1/comments/2')).to route_to('audio_event_comments#destroy', audio_event_id: '1', id: '2', format: 'json') }

      it { expect(get('/audio_event_comments')).to route_to('errors#route_error', requested_route: 'audio_event_comments') }

      it { expect(get('/audio_events/1/comments/filter')).to route_to('audio_event_comments#filter',audio_event_id: '1', format: 'json') }
      it { expect(post('/audio_events/1/comments/filter')).to route_to('audio_event_comments#filter', audio_event_id: '1', format: 'json') }
    end
end
