require 'spec_helper'

describe BookmarksController do
  describe :routing do

    it { expect(get('/user_accounts/1/bookmarks')).to route_to('bookmarks#index', user_account_id: '1', format: 'json') }

    it { expect(get('/audio_recordings/1/bookmarks')).to route_to('bookmarks#index', audio_recording_id: '1', format: 'json') }
    it { expect(post('/audio_recordings/1/bookmarks')).to route_to('bookmarks#create', audio_recording_id: '1', format: 'json') }
    it { expect(get('/audio_recordings/1/bookmarks/new')).to route_to('bookmarks#new', audio_recording_id: '1', format: 'json') }

    it { expect(get('/bookmarks/1/edit')).to route_to('bookmarks#edit', id: '1', format: 'json') }
    it { expect(get('/bookmarks/1')).to route_to('bookmarks#show', id: '1', format: 'json') }
    it { expect(put('/bookmarks/1')).to route_to('bookmarks#update', id: '1', format: 'json') }
    it { expect(delete('/bookmarks/1')).to route_to('bookmarks#destroy', id: '1', format: 'json') }

  end
end