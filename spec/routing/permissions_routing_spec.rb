require 'spec_helper'

describe PermissionsController do
  describe 'routing' do

    it 'routes to #index' do
      get('projects/1/permissions').should route_to('permissions#index', :project_id => '1')
    end

    it 'routes to #new' do
      get('projects/1//permissions/new').should route_to('permissions#new', :project_id => '1')
    end

    it 'routes to #show' do
      get('projects/1//permissions/1').should route_to('permissions#show', :id => '1', :project_id => '1', format: 'json')
    end

    it 'routes to #edit' do
      get('projects/1//permissions/1/edit').should route_to('permissions#edit', :id => '1', :project_id => '1')
    end

    it 'routes to #create' do
      post('projects/1//permissions').should route_to('permissions#create', :project_id => '1')
    end

    it 'routes to #update' do
      put('projects/1//permissions/1').should route_to('permissions#update', :id => '1', :project_id => '1')
    end

    it 'routes to #destroy' do
      delete('projects/1//permissions/1').should route_to('permissions#destroy', :id => '1', :project_id => '1')
    end

  end
end
