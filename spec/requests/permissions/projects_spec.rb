

describe 'Project permissions' do
  create_entire_hierarchy

  given_the_route '/projects' do
    {
      id: project.id
    }
  end
  using_the_factory :project
  for_lists_expects do |user, _action|
    case user
    when :admin
      Project.all
    when :owner, :reader, :writer
      project
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, can_do: (reading + creation), and_cannot_do: (writing - creation)

  the_user :no_access, can_do: (listing + creation), and_cannot_do: (not_listing - creation)

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized

  context 'with public project creation disabled' do
    before(:each) do
      allow(Settings.permissions).to receive(:any_user_can_create_projects) { false }
    end

    ensures :owner, :writer, :reader, :harvester, cannot: [:create]
  end
end
