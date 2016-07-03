require 'rails_helper'

describe PermissionsController, :type => :routing do
  describe :routing do

    it { expect(get('/user_accounts/1/permissions')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions') }
    it { expect(post('/user_accounts/1/permissions')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions') }
    it { expect(get('/user_accounts/1/permissions/new')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions/new') }
    it { expect(get('/user_accounts/1/permissions/2/edit')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions/2/edit') }
    it { expect(get('/user_accounts/1/permissions/2')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions/2') }
    it { expect(put('/user_accounts/1/permissions/2')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions/2') }
    it { expect(delete('/user_accounts/1/permissions/2')).to  route_to('errors#route_error', requested_route: 'user_accounts/1/permissions/2') }

    it { expect(get('/projects/1/permissions')).to route_to('permissions#index', project_id: '1') }

    it { expect(get('/projects/1/permissions/2')).to  route_to('permissions#show', project_id: '1', id: '2', format: 'json') }
    it { expect(post('/projects/1/permissions')).to  route_to('permissions#create', project_id: '1', format: 'json') }
    it { expect(get('/projects/1/permissions/new')).to  route_to('permissions#new', project_id: '1', format: 'json') }
    it { expect(get('/projects/1/permissions/2/edit')).to  route_to('errors#route_error', requested_route: 'projects/1/permissions/2/edit') }
    it { expect(put('/projects/1/permissions/2')).to  route_to('errors#route_error', requested_route: 'projects/1/permissions/2') }
    it { expect(delete('/projects/1/permissions/2')).to  route_to('permissions#destroy', project_id: '1', id: '2', format: 'json') }

  end
end