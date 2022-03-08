# frozen_string_literal: true

# this is a confusing set of tests:
# We are testing which users are allowed access to the permissions endpoint
# Hence permissions tests for permissions controller.
# Only an owner (or admin) can change permissions for their project.

describe 'Permission permissions' do
  create_entire_hierarchy

  given_the_route '/projects/{project_id}/permissions' do
    {
      id: reader_permission.id,
      project_id: project.id
    }
  end

  using_the_factory :permission, traits: [:owner], factory_args: -> { { project_id: project.id } }

  for_lists_expects do |user, _action|
    case user
    when :admin, :owner
      project.permissions
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything, and_cannot_do: nothing

  # permissions to change the permission for the project, only owners can do it
  the_users :writer, :reader, :no_access,
    can_do: listing, and_cannot_do: not_listing

  the_user :harvester, can_do: nothing, and_cannot_do: everything
  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
