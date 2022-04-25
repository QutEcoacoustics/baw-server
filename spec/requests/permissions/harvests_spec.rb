# frozen_string_literal: true

describe 'Harvest permissions' do
  # private projects are tested in the project tests, so we'll test
  # the more complex case where an anonymous user has access to a
  # project
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  given_the_route '/projects/{project_id}/harvests' do
    {
      project_id: project.id,
      id: harvest.id
    }
  end

  # not using  the factory because there are many tricky params that can only
  # be sent for some of update or delete, easier to hand craft
  send_update_body do
    [{ harvest: { mappings: nil } }, :json]
  end

  send_create_body do
    [{ harvest: { streaming: true } }, :json]
  end

  for_lists_expects do |user, _action|
    case user
    when :admin
      Harvest.all
    when :owner
      harvest
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything

  the_users :writer, :reader, :no_access, can_do: listing, and_cannot_do: not_listing

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end

describe 'Harvest permissions (shallow)' do
  # private projects are tested in the project tests, so we'll test
  # the more complex case where an anonymous user has access to a
  # project
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  given_the_route '/harvests' do
    {
      id: harvest.id
    }
  end

  # not using  the factory because there are many tricky params that can only
  # be sent for some of update or delete, easier to hand craft
  send_update_body do
    [{ harvest: { mappings: nil } }, :json]
  end

  send_create_body do
    [{ harvest: { streaming: true, project_id: project.id } }, :json]
  end

  for_lists_expects do |user, _action|
    case user
    when :admin
      Harvest.all
    when :owner
      harvest
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything

  the_users :writer, :reader, :no_access, can_do: listing, and_cannot_do: not_listing

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
