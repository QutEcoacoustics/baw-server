# frozen_string_literal: true

describe 'Harvest items permissions (nested)' do
  # private projects are tested in the project tests, so we'll test
  # the more complex case where an anonymous user has access to a
  # project
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest
  prepare_harvest_item

  given_the_route '/projects/{project_id}/harvests/{harvest_id}/items' do
    {
      project_id: project.id,
      harvest_id: harvest.id
    }
  end

  send_update_body do
    [{}, :json]
  end

  send_create_body do
    [{}, :json]
  end

  for_lists_expects do |user, _action|
    case user
    when :admin, :owner
      harvest.harvest_items
    else
      []
    end
  end

  with_custom_action(
    :index,
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
      expect(api_response).to include({
        summary: a_hash
      })
    }
  )

  # there's no point testing :new or :show - each of these have path suffixes
  # ('new' and '{id}', respectively) that are confused for the (/:path) route
  # parameter.
  do_not_check_permissions_for(all_users, [:new, :show])

  ensures :admin, :owner,
    can: [:index, :filter],
    cannot: [:create, :update, :destroy],
    fails_with: :not_found

  ensures :writer, :reader, :no_access, :anonymous,
    can: [:index, :filter],
    cannot: [],
    fails_with: :forbidden

  ensures :writer, :reader, :no_access, :harvester, :anonymous,
    can: [],
    cannot: [:create, :update, :destroy],
    fails_with: :not_found

  ensures :harvester,
    can: [],
    cannot: [:index, :filter]

  the_users :invalid,
    can_do: nothing,
    and_cannot_do: everything,
    fails_with: [:unauthorized, :not_found]
end

describe 'Harvest items permissions (shallow)' do
  # private projects are tested in the project tests, so we'll test
  # the more complex case where an anonymous user has access to a
  # project
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest
  prepare_harvest_item

  given_the_route '/harvests/{harvest_id}/items' do
    {
      project_id: project.id,
      harvest_id: harvest.id
    }
  end

  send_update_body do
    [{}, :json]
  end

  send_create_body do
    [{}, :json]
  end

  for_lists_expects do |user, _action|
    case user
    when :admin, :owner
      harvest.harvest_items
    else
      []
    end
  end

  with_custom_action(
    :index,
    path: '',
    verb: :get,
    expect: lambda { |_user, _action|
      expect(api_response).to include({
        summary: a_hash
      })
    }
  )

  # there's no point testing :new or :show - each of these have path suffixes
  # ('new' and '{id}', respectively) that are confused for the (/:path) route
  # parameter.
  do_not_check_permissions_for(all_users, [:new, :show])

  ensures :admin, :owner,
    can: [:index, :filter],
    cannot: [:create, :update, :destroy],
    fails_with: :not_found

  ensures :writer, :reader, :no_access, :anonymous,
    can: [:index, :filter],
    cannot: [],
    fails_with: :forbidden

  ensures :writer, :reader, :no_access, :harvester, :anonymous,
    can: [],
    cannot: [:create, :update, :destroy],
    fails_with: :not_found

  ensures :harvester,
    can: [],
    cannot: [:index, :filter]

  the_users :invalid,
    can_do: nothing,
    and_cannot_do: everything,
    fails_with: [:unauthorized, :not_found]
end
