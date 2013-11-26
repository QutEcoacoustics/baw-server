require 'spec_helper'

describe DatasetsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/datasets').should route_to('datasets#index', :project_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('/projects/1/datasets/new').should route_to('datasets#new', :project_id => '1')
    end

    it 'routes to #show' do
      get('/projects/1/datasets/1').should route_to('datasets#show', :id => '1', :project_id => '1')
    end

    it 'routes to #edit' do
      get('/projects/1/datasets/1/edit').should route_to('datasets#edit', :id => '1', :project_id => '1')
    end

    it 'routes to #create' do
      post('/projects/1/datasets').should route_to('datasets#create', :project_id => '1')
    end

    it 'routes to #update' do
      put('/projects/1/datasets/1').should route_to('datasets#update', :id => '1', :project_id => '1')
    end

    it 'routes to #destroy' do
      delete('/projects/1/datasets/1').should route_to('datasets#destroy', :id => '1', :project_id => '1')
    end

  end
end
