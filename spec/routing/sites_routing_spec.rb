require 'spec_helper'

describe SitesController do
  describe 'routing' do

    it 'routes to #index' do
      get('projects/1/sites').should route_to('sites#index', :project_id => '1', format: 'json')
    end

    it 'routes to #new' do
      get('projects/1/sites/new').should route_to('sites#new', :project_id => '1')
    end

    it 'routes to #show' do
      get('projects/1/sites/1').should route_to('sites#show', :id => '1', :project_id => '1')
    end

    it 'routes to #show_shallow' do
      get('/sites/1').should route_to('sites#show_shallow', :id => '1', format: 'json')
    end

    it 'routes to #edit' do
      get('projects/1/sites/1/edit').should route_to('sites#edit', :id => '1', :project_id => '1')
    end

    it 'routes to #create' do
      post('projects/1/sites').should route_to('sites#create', :project_id => '1')
    end

    it 'routes to #update' do
      put('projects/1/sites/1').should route_to('sites#update', :id => '1', :project_id => '1')
    end

    it 'routes to #destroy' do
      delete('projects/1/sites/1').should route_to('sites#destroy', :id => '1', :project_id => '1')
    end

  end
end
