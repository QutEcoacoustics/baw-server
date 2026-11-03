# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/audio_recordings_spec.rb.

describe 'AudioRecording permissions' do
  create_audio_recordings_hierarchy

  given_the_route '' do
    {
      id: audio_recording.id,
      project_id: project.id,
      site_id: site.id,
      uploader_id: writer_user.id
    }
  end

  send_create_body do
    [
      { audio_recording: attributes_for(:audio_recording, site_id: site.id, uploader_id: writer_user.id) },
      :json
    ]
  end

  send_update_body do
    [{ audio_recording: { duration_seconds: 70.0 } }, :json]
  end

  for_lists_expects do |user, _action|
    [:admin, :owner, :writer, :reader].include?(user) ? [audio_recording] : []
  end

  {
    index: ['', :get, :list],
    show: ['{id}', :get, :single],
    new: ['new', :get, :template],
    filter: ['filter', :post, :list],
    update: ['{id}', :put, :single]
  }.each do |action, (path, verb, expected)|
    with_custom_action action, path: "audio_recordings/#{path}", verb:, expect: expected,
      body: action == :update ? :update : nil
  end

  with_custom_action :create,
    path: 'projects/{project_id}/sites/{site_id}/audio_recordings',
    verb: :post, expect: :created, body: :create

  with_custom_action :nested_new,
    path: 'projects/{project_id}/sites/{site_id}/audio_recordings/new',
    verb: :get, expect: :template

  with_custom_action :check_uploader,
    path: 'projects/{project_id}/sites/{site_id}/audio_recordings/check_uploader/{uploader_id}',
    verb: :get, expect: :nothing

  with_custom_action :update_status,
    path: 'audio_recordings/{id}/update_status',
    verb: :put, expect: :nothing,
    body: lambda {
      [{ file_hash: audio_recording.file_hash, uuid: audio_recording.uuid, status: 'uploading' }, :json]
    }

  # Audio recordings have no destroy route.
  do_not_check_permissions_for PermissionsHelpers::ExampleGroup::STANDARD_USERS, [:destroy]

  the_user :admin, can_do: (reading + [:create, :update, :nested_new]),
    and_cannot_do: [:check_uploader, :update_status]
  the_user :harvester, can_do: [:new, :nested_new, :create, :update, :check_uploader, :update_status],
    and_cannot_do: [:index, :filter, :show]
  the_users :owner, :writer, :reader, can_do: (reading + [:nested_new]),
    and_cannot_do: [:create, :update, :check_uploader, :update_status]
  the_user :no_access, can_do: listing,
    and_cannot_do: [:show, :nested_new, :create, :update, :check_uploader, :update_status]
  the_user :anonymous, can_do: listing,
    and_cannot_do: [:show, :nested_new, :create, :update, :check_uploader, :update_status],
    fails_with: :unauthorized
  the_user :invalid, can_do: nothing,
    and_cannot_do: (everything - [:destroy]), fails_with: :unauthorized
end
