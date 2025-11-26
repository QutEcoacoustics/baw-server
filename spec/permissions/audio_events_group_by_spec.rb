# frozen_string_literal: true

describe AudioEvents::GroupByController do
  describe 'permissions' do
    create_entire_hierarchy

    given_the_route '/audio_events/group_by' do
      {
        id: :invalid
      }
    end

    send_create_body do
      [{}, :json]
    end

    send_update_body do
      [{}, :json]
    end

    with_custom_action(
      :sites,
      path: 'sites',
      verb: :get,
      expect: lambda { |_user, _action|
        expect(api_response).to include(:data)
      }
    )

    # Any authenticated user with at least reader access can use the group_by endpoint
    ensures :admin, :owner, :writer, :reader,
      can: [:sites],
      cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
      fails_with: :not_found

    # Users without project access cannot see any results (empty response but still succeeds)
    ensures :no_access,
      can: [:sites],
      cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
      fails_with: :not_found

    # Harvester cannot access the endpoint
    ensures :harvester,
      cannot: [:sites],
      fails_with: :forbidden

    ensures :harvester,
      cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
      fails_with: :not_found

    # Anonymous users can access the endpoint
    ensures :anonymous,
      can: [:sites]

    ensures :anonymous,
      cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
      fails_with: :not_found

    # Invalid tokens cannot access the endpoint
    ensures :invalid,
      cannot: [:sites, :index, :show, :create, :update, :destroy, :new, :filter],
      fails_with: [:unauthorized, :not_found]
  end
end
