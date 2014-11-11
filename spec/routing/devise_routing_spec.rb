require 'spec_helper'

describe SessionsController do
  describe :routing do

    it { expect(get('/my_account/sign_in')).to route_to('devise/sessions#new') }
    it { expect(post('/my_account/sign_in')).to route_to('devise/sessions#create') }
    it { expect(get('/my_account/sign_out')).to route_to('devise/sessions#destroy') }

    it { expect(post('/my_account/password')).to route_to('devise/passwords#create') }
    it { expect(get('/my_account/password/new')).to route_to('devise/passwords#new') }
    it { expect(get('/my_account/password/edit')).to route_to('devise/passwords#edit') }
    it { expect(put('/my_account/password')).to route_to('devise/passwords#update') }

    it { expect(get('/my_account/cancel')).to route_to('devise/registrations#cancel') }
    it { expect(post('/my_account')).to route_to('devise/registrations#create') }
    it { expect(get('/my_account/sign_up')).to route_to('devise/registrations#new') }
    it { expect(get('/my_account/edit')).to route_to('devise/registrations#edit') }
    it { expect(put('/my_account')).to route_to('devise/registrations#update') }
    it { expect(delete('/my_account')).to route_to('devise/registrations#destroy') }

    it { expect(post('/my_account/confirmation')).to route_to('devise/confirmations#create') }
    it { expect(get('/my_account/confirmation/new')).to route_to('devise/confirmations#new') }
    it { expect(get('/my_account/confirmation')).to route_to('devise/confirmations#show') }

    it { expect(post('/my_account/unlock')).to route_to('devise/unlocks#create') }
    it { expect(get('/my_account/unlock/new')).to route_to('devise/unlocks#new') }
    it { expect(get('/my_account/unlock')).to route_to('devise/unlocks#show') }

    it { expect(get('/security/new')).to route_to('sessions#new', format: 'json') }
    it { expect(post('/security')).to route_to('sessions#create', format: 'json') }
    it { expect(delete('/security')).to route_to('sessions#destroy', format: 'json') }
    it { expect(get('/security/user')).to route_to('sessions#show', format: 'json') }

  end
end