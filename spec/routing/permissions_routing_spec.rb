require 'spec_helper'

describe PermissionsController do
  describe :routing do

    it { expect(get('/user_accounts/1/permissions')).to  route_to('permissions#index', user_account_id: '1') }
    it { expect(post('/user_accounts/1/permissions')).to  route_to('permissions#create', user_account_id: '1') }
    it { expect(get('/user_accounts/1/permissions/new')).to  route_to('permissions#new', user_account_id: '1') }
    it { expect(get('/user_accounts/1/permissions/2/edit')).to  route_to('permissions#edit', user_account_id: '1', id: '2') }
    it { expect(get('/user_accounts/1/permissions/2')).to  route_to('permissions#show',  user_account_id: '1', id: '2') }
    it { expect(put('/user_accounts/1/permissions/2')).to  route_to('permissions#update', user_account_id: '1', id: '2') }
    it { expect(delete('/user_accounts/1/permissions/2')).to  route_to('permissions#destroy',  user_account_id: '1', id: '2') }

    it { expect(get('/projects/1/permissions')).to route_to('permissions#index', project_id: '1') }
    it { expect(post('/projects/1/permissions')).to  route_to('permissions#create', project_id: '1') }
    it { expect(get('/projects/1/permissions/new')).to  route_to('permissions#new', project_id: '1') }
    it { expect(get('/projects/1/permissions/2/edit')).to  route_to('permissions#edit', project_id: '1', id: '2') }
    it { expect(put('/projects/1/permissions/2')).to  route_to('permissions#update', project_id: '1', id: '2') }
    it { expect(delete('/projects/1/permissions/2')).to  route_to('permissions#destroy', project_id: '1', id: '2') }

    it { expect(get('/projects/1/permissions/2')).to  route_to('permissions#show', project_id: '1', id: '2', format: 'json') }

  end
end
