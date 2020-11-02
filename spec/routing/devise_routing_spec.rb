# frozen_string_literal: true

require 'rails_helper'

describe SessionsController, type: :routing do
  describe :routing do
    it { expect(get('/my_account/sign_in')).to route_to('users/sessions#new') }
    it { expect(post('/my_account/sign_in')).to route_to('users/sessions#create') }
    it { expect(get('/my_account/sign_out')).to route_to('users/sessions#destroy') }

    it { expect(post('/my_account/password')).to route_to('devise/passwords#create') }
    it { expect(get('/my_account/password/new')).to route_to('devise/passwords#new') }
    it { expect(get('/my_account/password/edit')).to route_to('devise/passwords#edit') }
    it { expect(put('/my_account/password')).to route_to('devise/passwords#update') }

    it { expect(get('/my_account/cancel')).to route_to('users/registrations#cancel') }
    it { expect(post('/my_account')).to route_to('users/registrations#create') }
    it { expect(get('/my_account/sign_up')).to route_to('users/registrations#new') }
    it { expect(get('/my_account/edit')).to route_to('users/registrations#edit') }
    it { expect(put('/my_account')).to route_to('users/registrations#update') }
    it { expect(delete('/my_account')).to route_to('users/registrations#destroy') }

    it { expect(post('/my_account/confirmation')).to route_to('devise/confirmations#create') }
    it { expect(get('/my_account/confirmation/new')).to route_to('devise/confirmations#new') }
    it { expect(get('/my_account/confirmation')).to route_to('devise/confirmations#show') }

    it { expect(post('/my_account/unlock')).to route_to('devise/unlocks#create') }
    it { expect(get('/my_account/unlock/new')).to route_to('devise/unlocks#new') }
    it { expect(get('/my_account/unlock')).to route_to('devise/unlocks#show') }

    it { expect(get('/security/new')).to route_to('sessions#new', format: 'json') }
    it { expect(delete('/security')).to route_to('sessions#destroy', format: 'json') }

    # used by harvester
    it { expect(post('/security')).to route_to('sessions#create', format: 'json') }

    # used by client
    it { expect(get('/security/user')).to route_to('sessions#show', format: 'json') }
  end
end
