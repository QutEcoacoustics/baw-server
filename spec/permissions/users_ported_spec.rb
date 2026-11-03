# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/user_accounts_spec.rb.

describe 'User account permissions (ported)' do
  prepare_users

  before_request do |user, _action|
    @permission_user = user
  end

  given_the_route '' do
    self_id = if [:anonymous, :invalid].include?(@permission_user)
                writer_user.id
              else
                public_send(:"#{@permission_user}_user").id
              end

    { id: writer_user.id, self_id: }
  end

  send_update_body do
    [{ user: { user_name: 'ported profile' } }, :json]
  end

  for_lists_expects do |_user, _action|
    writer_user
  end

  with_custom_action :index, path: 'user_accounts', verb: :get, expect: :list
  with_custom_action :show, path: 'user_accounts/{id}', verb: :get, expect: :single
  with_custom_action :update, path: 'user_accounts/{id}', verb: :put, expect: :single, body: :update
  with_custom_action :filter, path: 'user_accounts/filter', verb: :post, expect: :list,
    body: -> { [{ filter: { id: { eq: writer_user.id } } }, :json] }

  [:show_self, :update_self].each do |action|
    with_custom_action action,
      path: 'user_accounts/{self_id}',
      verb: action == :show_self ? :get : :put,
      body: action == :show_self ? nil : :update,
      expect: lambda { |_user, _action|
        expect(api_data).to include(id: route_params[:self_id])
      }
  end

  with_custom_action :my_account, path: 'my_account', verb: :get,
    expect: lambda { |_user, _action|
      expect(api_data).to include(id: route_params[:self_id])
    }

  with_custom_action :preferences, path: 'my_account/prefs', verb: :put,
    body: [{ user_account: { volume: 1, muted: false } }, :json],
    expect: lambda { |_user, _action|
      expect(api_data).to include(id: route_params[:self_id])
    }

  do_not_check_permissions_for all_users, [:create, :destroy, :new]
  # Admin JSON-index negotiation is covered by the ported API contract, not an access denial.
  do_not_check_permissions_for [:admin], [:index]
  supported_actions = everything - [:create, :destroy, :new]

  ensures :admin, can: supported_actions - [:index]

  ensures :writer, can: supported_actions - [:index], cannot: [:index]
  ensures :owner, :reader, :no_access,
    can: supported_actions - [:index, :update],
    cannot: [:index, :update]

  ensures :harvester, cannot: supported_actions
  ensures :anonymous, :invalid, cannot: supported_actions, fails_with: :unauthorized
end
