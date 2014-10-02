require 'spec_helper'

describe BookmarksController do
  describe :routing do

    it { expect(get('/bookmarks')).to route_to('bookmarks#index') }
    it { expect(post('/bookmarks')).to route_to('bookmarks#create') }
    it { expect(get('/bookmarks/new')).to route_to('bookmarks#new') }
    it { expect(get('/bookmarks/1')).to route_to('bookmarks#show', id: '1') }
    it { expect(put('/bookmarks/1')).to route_to('bookmarks#update', id: '1') }
    it { expect(delete('/bookmarks/1')).to route_to('bookmarks#destroy', id: '1') }

    it { expect(get('bookmarks/filter')).to route_to('bookmarks#filter', format: 'json') }
    it { expect(post('bookmarks/filter')).to route_to('bookmarks#filter', format: 'json') }
  end
end