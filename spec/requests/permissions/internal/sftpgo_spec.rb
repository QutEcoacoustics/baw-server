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

  valid_hook_post = {
    path: '',
    verb: :post,
    expect: lambda { |_user, _action|
            },
    action: :hook
  }

  # ok this one is a little weird
  # none of our normal users are allowed to access this endpoint
  # only the other service (sftpgo) is allowed and it does not authenticate
  # so if there are any auth tokens present, then access denied, even if it is a valid token!
  ensures :admin, :owner, :writer, :reader, :no_access, :harvester,
    can: nothing,
    cannot: [valid_hook_post]

  ensures :anonymous,
    can: nothing,
    cannot: [valid_hook_post],
    fails_with: :unauthorized

  the_user :invalid,
    can_do: nothing,
    and_cannot_do: everything,
    fails_with: :unauthorized
end
