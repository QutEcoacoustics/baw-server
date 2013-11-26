require 'spec_helper'

describe UserAccountsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/user_accounts').should route_to('user_accounts#index')
    end

    it 'routes to #new' do
      get('/user_accounts/new').should route_to('user_accounts#new')
    end

    it 'routes to #show' do
      get('/user_accounts/1').should route_to('user_accounts#show', :id => '1')
    end

    it 'routes to #edit' do
      get('/user_accounts/1/edit').should route_to('user_accounts#edit', :id => '1')
    end

    it 'routes to #create' do
      post('/user_accounts').should route_to('user_accounts#create')
    end

    it 'routes to #update' do
      put('/user_accounts/1').should route_to('user_accounts#update', :id => '1')
    end

    it 'routes to #destroy' do
      delete('/user_accounts/1').should route_to('user_accounts#destroy', :id => '1')
    end

  end
end
