# frozen_string_literal: true

describe 'Status permissions' do
  create_entire_hierarchy

  given_the_route '/status' do
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

  with_custom_action(:index, path: '', verb: :get, expect: lambda { |_user, _action|
    expect(api_response).to include({ status: 'good' })
  })

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
    can: [:index],
    cannot: [:create, :update, :destroy, :show, :new, :filter],
    fails_with: :not_found

  the_user :invalid,
    can_do: nothing,
    and_cannot_do: everything,
    fails_with: [:unauthorized, :not_found]
end
