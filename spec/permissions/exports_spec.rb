# frozen_string_literal: true

# Only a project owner can create an export, so the project owner is also the export's creator.
# The creator is the only user who can show, download or destroy the export.
describe 'Export permissions' do
  create_audio_recordings_hierarchy
  ignore_pending_jobs

  let!(:export) {
    create(:export, :with_zip_file, creator: owner_user, project:, status: 'ready')
  }

  given_the_route '/exports' do
    { id: export.id }
  end

  send_create_body do
    [{ export: { export_type: 'camtrap_dp', name: 'permissions', project_id: project.id, filter: {} } }, :json]
  end

  send_update_body { nil }

  with_custom_action(:download, path: '{id}/download', verb: :get, expect: ->(_user, _action) {})

  for_lists_expects do |user, _action|
    case user
    when :admin
      Export.all
    when :owner
      export
    else
      []
    end
  end

  the_user :admin, can_do: everything_but_update, and_cannot_do: []

  # the update route does not exist
  ensures(*all_users, cannot: :update, fails_with: :not_found)

  the_user :owner, can_do: everything_but_update, and_cannot_do: []

  # users who are not the project owner can list exports (they only see their own) but cannot create or access one
  the_users :writer, :reader, :no_access,
    can_do: listing,
    and_cannot_do: not_listing - [:update]

  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing - [:update], fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end

# Access follows the creator, not the project permissions. The writer stands in for
# a creator who is no longer a project owner.
describe 'Export permissions (creator is not a project owner)' do
  create_audio_recordings_hierarchy
  ignore_pending_jobs

  let!(:export) {
    create(:export, :with_zip_file, creator: writer_user, project:, status: 'ready')
  }

  given_the_route '/exports' do
    { id: export.id }
  end

  send_create_body do
    [{ export: { export_type: 'camtrap_dp', name: 'permissions', project_id: project.id, filter: {} } }, :json]
  end

  send_update_body { nil }

  with_custom_action(:download, path: '{id}/download', verb: :get, expect: ->(_user, _action) {})

  for_lists_expects do |user, _action|
    case user
    when :admin
      Export.all
    when :writer
      export
    else
      []
    end
  end

  the_user :admin, can_do: everything_but_update, and_cannot_do: []

  ensures(*all_users, cannot: :update, fails_with: :not_found)

  # the creator keeps access to their export but can no longer create one
  the_user :writer, can_do: everything_but_update - creation, and_cannot_do: creation

  # a project owner can create exports but cannot access one created by someone else
  the_user :owner, can_do: listing + creation, and_cannot_do: not_listing - creation - [:update]

  the_users :reader, :no_access,
    can_do: listing,
    and_cannot_do: not_listing - [:update]

  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing - [:update], fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end
