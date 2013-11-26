require 'spec_helper'

describe BookmarksController do
  describe 'routing' do

    it 'routes to #index' do
      get('/user_accounts/1/bookmarks').should route_to('bookmarks#index', :user_account_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('audio_recordings/1/bookmarks/new').should route_to('bookmarks#new', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #show' do
      get('/bookmarks/1').should route_to('bookmarks#show', :id => '1', format: 'json')
    end

    it 'routes to #edit' do
      get('/bookmarks/1/edit').should route_to('bookmarks#edit', :id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('audio_recordings/1/bookmarks').should route_to('bookmarks#create', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/bookmarks/1').should route_to('bookmarks#update', :id => '1', format: 'json')
    end

    it 'routes to #destroy' do
      delete('/bookmarks/1').should route_to('bookmarks#destroy', :id => '1', format: 'json')
    end

  end
end
