# frozen_string_literal: true

describe 'Stats permissions' do
  create_entire_hierarchy

  given_the_route '/stats' do
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
    expect(api_data).to include({
      summary: a_kind_of(Hash)
    })
  })

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
    can: [:index],
    cannot: [:create, :update, :destroy, :new, :filter, :show],
    fails_with: :not_found

  ensures :invalid,
    cannot: [:index],
    fails_with: :unauthorized

  ensures :invalid,
    cannot: everything - [:index],
    fails_with: :not_found
end
