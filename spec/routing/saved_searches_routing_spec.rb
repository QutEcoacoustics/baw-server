require 'spec_helper'

describe SavedSearchesController, :type => :routing do
  describe :routing do

    it { expect(get('/user_accounts/1/saved_searches')).to route_to('user_accounts#saved_searches', id: '1') }

    it { expect(get('/saved_searches')).to route_to('saved_searches#index', format: 'json') }
    it { expect(post('/saved_searches')).to route_to('saved_searches#create', format: 'json') }
    it { expect(get('/saved_searches/new')).to route_to('saved_searches#new', format: 'json') }

    it { expect(get('/saved_searches/2/edit')).to route_to('errors#route_error', requested_route: 'saved_searches/2/edit') }

    it { expect(put('/saved_searches/2')).to route_to('saved_searches#update', id: '2', format: 'json') }
    it { expect(delete('/saved_searches/2')).to route_to('saved_searches#destroy', id: '2', format: 'json') }

    # used by client
    it { expect(get('/saved_searches/2')).to route_to('saved_searches#show', id: '2', format: 'json') }

    it { expect(get('/saved_searches/filter')).to route_to('saved_searches#filter', format: 'json') }
    it { expect(post('/saved_searches/filter')).to route_to('saved_searches#filter', format: 'json') }

  end
end
