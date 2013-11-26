require 'spec_helper'

describe JobsController do
  describe 'routing' do

    it 'routes to #index' do
      get('/projects/1/jobs').should route_to('jobs#index', :project_id => '1', :format=> 'json')
    end

    it 'routes to #index' do
      get('/projects/1/datasets/1/jobs').should route_to('jobs#index', :project_id => '1', :dataset_id => '1', :format=> 'json')
    end

    it 'routes to #new' do
      get('/projects/1/jobs/new').should route_to('jobs#new', :project_id => '1')
    end

    it 'routes to #show' do
      get('/projects/1/datasets/1/jobs/1').should route_to('jobs#show', :id => '1', :project_id => '1', :dataset_id => '1')
    end

    it 'routes to #edit' do
      get('/projects/1/jobs/1/edit').should route_to('jobs#edit', :id => '1', :project_id => '1')
    end

    it 'routes to #create' do
      post('/projects/1/jobs').should route_to('jobs#create', :project_id => '1')
    end

    it 'routes to #update' do
      put('/projects/1/jobs/1').should route_to('jobs#update', :id => '1', :project_id => '1')
    end

    it 'routes to #destroy' do
      delete('/projects/1/jobs/1').should route_to('jobs#destroy', :id => '1', :project_id => '1')
    end

  end
end
