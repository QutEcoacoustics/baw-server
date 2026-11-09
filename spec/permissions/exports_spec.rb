# frozen_string_literal: true

# A project reader (or above) can create an export, here the project owner.
# The creator is the only user who can show, download or destroy the export (not
# including downloads via token).
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

  # can list (sees only own exports), can create,
  # but cannot show/download/destroy the owner's export (the owner is the export's creator)
  the_users :writer, :reader,
    can_do: listing + creation,
    and_cannot_do: not_listing - creation - [:update]

  # users without access to the project can list exports (they only see their own) but cannot create or access one
  the_user :no_access,
    can_do: listing,
    and_cannot_do: not_listing - [:update]

  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing - [:update], fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end
