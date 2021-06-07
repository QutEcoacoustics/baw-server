# frozen_string_literal: true



describe UserAccountsController, type: :routing do
  describe :routing do
    it { expect(get('/user_accounts')).to route_to('user_accounts#index') }
    it { expect(post('/user_accounts')).to route_to('errors#route_error', requested_route: 'user_accounts') }
    it { expect(get('/user_accounts/new')).to route_to('errors#route_error', requested_route: 'user_accounts/new') }
    it { expect(get('/user_accounts/1/edit')).to route_to('user_accounts#edit', id: '1') }
    it { expect(get('/user_accounts/1')).to route_to('user_accounts#show', id: '1') }
    it { expect(put('/user_accounts/1')).to route_to('user_accounts#update', id: '1') }
    it { expect(patch('/user_accounts/1')).to route_to('user_accounts#update', id: '1') }
    it { expect(delete('/user_accounts/1')).to route_to('errors#route_error', requested_route: 'user_accounts/1') }

    it { expect(get('/user_accounts/1/projects')).to route_to('user_accounts#projects', id: '1') }
    it { expect(get('/user_accounts/1/sites')).to route_to('user_accounts#sites', id: '1') }
    it { expect(get('/user_accounts/1/bookmarks')).to route_to('user_accounts#bookmarks', id: '1') }
    it { expect(get('/user_accounts/1/audio_events')).to route_to('user_accounts#audio_events', id: '1') }
    it { expect(get('/user_accounts/1/audio_event_comments')).to route_to('user_accounts#audio_event_comments', id: '1') }
    it { expect(get('/user_accounts/1/saved_searches')).to route_to('user_accounts#saved_searches', id: '1') }
    it { expect(get('/user_accounts/1/analysis_jobs')).to route_to('user_accounts#analysis_jobs', id: '1') }

    # used by client
    it { expect(get('/my_account/')).to route_to('user_accounts#my_account') }
    it { expect(put('/my_account/prefs')).to route_to('user_accounts#modify_preferences') }

    it { expect(get('/user_accounts/filter')).to route_to('user_accounts#filter', format: 'json') }
    it { expect(post('/user_accounts/filter')).to route_to('user_accounts#filter', format: 'json') }
  end
end
