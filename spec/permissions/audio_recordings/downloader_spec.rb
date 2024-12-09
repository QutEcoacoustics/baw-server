# frozen_string_literal: true

describe 'AudioRecordings::DownloaderController permissions' do
  create_entire_hierarchy

  given_the_route '/audio_recordings/downloader' do
    {
      id: :invalid
    }
  end

  with_idempotent_requests_only

  {
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
              expect_success
            },
    action: :index
  }

  with_custom_action(
    :downloader_action,
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
              expect_success
            }
  )

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
    can: [:downloader_action],
    cannot: nothing,
    fails_with: :forbidden

  ensures :invalid,
    can: nothing,
    cannot: [:downloader_action],
    fails_with: :unauthorized

  do_not_check_permissions_for(all_users, everything)
end
