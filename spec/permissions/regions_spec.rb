# frozen_string_literal: true

describe 'Region permissions' do
  create_entire_hierarchy

  given_the_route '/regions' do
    {
      id: region.id
    }
  end
  using_the_factory :region, factory_args: -> { { project_id: project.id } }
  for_lists_expects do |user, _action|
    case user
    when :admin
      Region.all
    when :owner, :reader, :writer
      region
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, can_do: reading, and_cannot_do: writing

  the_user :no_access, can_do: listing, and_cannot_do: not_listing

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
