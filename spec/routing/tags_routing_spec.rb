require 'spec_helper'

describe TagsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/1/tags').should route_to('tags#index', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #index' do
      get('tags').should route_to('tags#index', format: 'json')
    end

    it 'routes to #new' do
      get('/tags/new').should route_to('tags#new', format: 'json')
    end

    it 'routes to #show' do
      get('tags/1').should route_to('tags#show', :id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('tags').should route_to('tags#create', format: 'json')
    end

    it 'routes to #update' do
      put('tags/1').should route_to('tags#update', :id => '1', format: 'json')
    end

    it 'routes to #index' do
      get('audio_recordings/1/audio_events/1/tags').should route_to('tags#index', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

  end
end
