require 'rails_helper'

describe UserAccountsController, :type => :routing do
  describe :routing do

    it { expect(get('/user_accounts')).to route_to('user_accounts#index') }
    it { expect(post('/user_accounts')).to route_to('errors#route_error', requested_route: 'user_accounts') }
    it { expect(get('/user_accounts/new')).to route_to('errors#route_error', requested_route: 'user_accounts/new') }
    it { expect(get('/user_accounts/1/edit')).to route_to('user_accounts#edit', id: '1') }
    it { expect(get('/user_accounts/1')).to route_to('user_accounts#show', id: '1') }
    it { expect(put('/user_accounts/1')).to route_to('user_accounts#update', id: '1') }
    it { expect(delete('/user_accounts/1')).to route_to('errors#route_error', requested_route: 'user_accounts/1') }

    # used by client
    it { expect(get('/my_account/')).to route_to('user_accounts#my_account') }
    it { expect(put('/my_account/prefs')).to route_to('user_accounts#modify_preferences') }

    it { expect(get('/user_accounts/filter')).to route_to('user_accounts#filter', format: 'json') }
    it { expect(post('/user_accounts/filter')).to route_to('user_accounts#filter', format: 'json') }

  end
end