# frozen_string_literal: true

describe 'Provenance permissions' do
  create_entire_hierarchy

  given_the_route '/provenances' do
    {
      id: provenance.id
    }
  end
  using_the_factory :provenance
  for_lists_expects do |user, _action|
    if user
      Provenance.all
    else
      []
    end
  end

  the_users :admin, can_do: everything
  the_users :owner, :writer, :reader, :no_access, can_do: reading, and_cannot_do: writing

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: reading, and_cannot_do: writing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
