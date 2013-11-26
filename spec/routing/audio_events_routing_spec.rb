require 'spec_helper'

describe AudioEventsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events').should route_to('audio_events#index', :project_id => '1', :site_id => '1',  :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #index' do
      get('/audio_recordings/1/audio_events').should route_to('audio_events#index', :audio_recording_id => '1', format: 'json')
    end


    it 'routes to #new' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/new').should route_to('audio_events#new', :project_id => '1', :site_id => '1', :audio_recording_id => '1',  format: 'json')
    end

    it 'routes to #show' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/1').should route_to('audio_events#show', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #show' do
      get('/audio_recordings/1/audio_events/1').should route_to('audio_events#show', :id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('/projects/1/sites/1/audio_recordings/1/audio_events').should route_to('audio_events#create', :project_id => '1', :site_id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('/projects/1/sites/1/audio_recordings/1/audio_events').should route_to('audio_events#create', :project_id => '1', :site_id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/projects/1/sites/1/audio_recordings/1/audio_events/1').should route_to('audio_events#update', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/audio_recordings/1/audio_events/1').should route_to('audio_events#update', :id => '1', :audio_recording_id => '1', format: 'json')
    end

    it 'routes to #destroy' do
      delete('/projects/1/sites/1/audio_recordings/1/audio_events/1').should route_to('audio_events#destroy', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', format: 'json')
    end

  end
end
