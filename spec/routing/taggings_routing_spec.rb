require 'spec_helper'

describe TaggingsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings').should route_to('taggings#index', :project_id => '1', :site_id => '1',  :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings/new').should route_to('taggings#new', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1',  format: 'json')
    end

    it 'routes to #show' do
      get('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#show', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings').should route_to('taggings#create', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#update', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #destroy' do
      delete('/projects/1/sites/1/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#destroy', :id => '1', :project_id => '1', :site_id => '1', :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #index' do
      get('/audio_recordings/1/audio_events/1/taggings').should route_to('taggings#index',   :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('/audio_recordings/1/audio_events/1/taggings/new').should route_to('taggings#new',  :audio_recording_id => '1', :audio_event_id => '1',  format: 'json')
    end

    it 'routes to #show' do
      get('/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#show', :id => '1',  :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('/audio_recordings/1/audio_events/1/taggings').should route_to('taggings#create',  :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#update', :id => '1',  :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

    it 'routes to #destroy' do
      delete('/audio_recordings/1/audio_events/1/taggings/1').should route_to('taggings#destroy', :id => '1',  :audio_recording_id => '1', :audio_event_id => '1', format: 'json')
    end

  end
end
