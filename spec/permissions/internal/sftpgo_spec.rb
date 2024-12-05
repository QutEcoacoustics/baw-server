# frozen_string_literal: true

describe 'Internal::SftpgoController permissions' do
  create_audio_recordings_hierarchy

  given_the_route '/internal/sftpgo/hook' do
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

  with_custom_action(:hook, path: '', verb: :post, expect: ->(_user, _action) {})

  # ok this one is a little weird
  # none of our normal users are allowed to access this endpoint
  # only the other service (sftpgo) is allowed and it does not authenticate
  # so if there are any auth tokens present, then access denied, even if it is a valid token!
  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous, :invalid,
    can: nothing,
    cannot: everything - [:hook, :create],
    fails_with: :not_found

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester,
    can: nothing,
    cannot: [:hook, :create],
    fails_with: :forbidden

  ensures :anonymous, :invalid,
    can: nothing,
    cannot: [:hook, :create],
    fails_with: :unauthorized
end
