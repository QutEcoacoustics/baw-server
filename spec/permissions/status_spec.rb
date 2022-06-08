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

  custom_index = {
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
              expect(api_response).to include({
                status: 'good'
              })
            },
    action: :index
  }

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
          can: [custom_index],
          cannot: [:create, :update, :destroy],
          fails_with: :not_found

  the_user :invalid,
           can_do: nothing,
           and_cannot_do: everything,
           fails_with: :unauthorized
end
