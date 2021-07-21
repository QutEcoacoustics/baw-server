# frozen_string_literal: true

describe 'Stats permissions' do
  create_entire_hierarchy

  given_the_route '/stats' do
    {}
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
                summary: a_hash
              })
            },
    action: :index
  }

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous, :invalid,
          can: [custom_index],
          cannot: [:create, :update, :destroy],
          fails_with: :not_found
end
