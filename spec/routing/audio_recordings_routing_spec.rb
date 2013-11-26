require 'spec_helper'

describe AudioRecordingsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/sites/1/audio_recordings').should route_to('audio_recordings#index', :project_id => '1', :site_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('/projects/1/sites/1/audio_recordings/new').should route_to('audio_recordings#new', :project_id => '1', :site_id => '1', format: 'json')
    end

    it 'routes to #show' do
      get('/projects/1/sites/1/audio_recordings/1').should route_to('audio_recordings#show', :id => '1', :project_id => '1', :site_id => '1', format: 'json')
    end

    it 'routes to #create' do
      post('/projects/1/sites/1/audio_recordings').should route_to('audio_recordings#create', :project_id => '1', :site_id => '1', format: 'json')
    end

    it 'routes to #check_uploader' do
      get('/projects/1/sites/1/audio_recordings/check_uploader').should route_to('audio_recordings#check_uploader', :project_id => '1', :site_id => '1', format: 'json')
    end

    it 'routes to #update' do
      put('/audio_recordings/1/update_status').should route_to('audio_recordings#update_status', :id => '1', format: 'json')
    end

    it 'routes to #show' do
      get('audio_recordings/1').should route_to('audio_recordings#show', :id => '1', format: 'json')
    end

  end
end
