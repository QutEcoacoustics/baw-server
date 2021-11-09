# frozen_string_literal: true

describe 'AudioRecordings::DownloaderController permissions' do
  create_entire_hierarchy

  given_the_route '/audio_recordings/downloader' do
    {
      id: :invalid
    }
  end

  with_idempotent_requests_only

  downloader_action = {
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
              expect_success
            },
    action: :index
  }

  ensures :admin, :owner, :writer, :reader, :no_access, :harvester, :anonymous,
    can: [downloader_action],
    cannot: nothing,
    fails_with: :forbidden

  ensures :invalid,
    can: nothing,
    cannot: [downloader_action],
    fails_with: :unauthorized
end
