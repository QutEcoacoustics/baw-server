require 'rails_helper'

describe 'Project permissions' do
  given_the_route '/projects' do
    {
      id: project.id
    }
  end
  using_the_factory :project
  and_validates_list_results do |user, _action|
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
end

# describe 'Project permissions (anonymous read access)' do
#   given_the_route '/projects' do
#     {
#       id: project.id
#     }
#   end
#   using_the_factory :project
#
#   the_user :admin, can_do: everything
#   the_user :owner, can_do: everything
#   the_user :writer, can_do: reading, and_cannot_do: writing
#   the_user :reader, can_do: reading, and_cannot_do: writing
#   the_user :no_access, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :invalid, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :anonymous, can_do: reading, and_cannot_do: writing
# end
#
# describe 'Project permissions (anonymous write access)' do
#   given_the_route '/projects' do
#     {
#       id: project.id
#     }
#   end
#   using_the_factory :project
#
#   the_user :admin, can_do: everything
#   the_user :owner, can_do: everything
#   the_user :writer, can_do: reading, and_cannot_do: writing
#   the_user :reader, can_do: reading, and_cannot_do: writing
#   the_user :no_access, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :invalid, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :anonymous, can_do: reading, and_cannot_do: writing
# end
#
# describe 'Project permissions (logged in read access)' do
#   given_the_route '/projects' do
#     {
#       id: project.id
#     }
#   end
#   using_the_factory :project
#
#   the_user :admin, can_do: everything
#   the_user :owner, can_do: everything
#   the_user :writer, can_do: reading, and_cannot_do: writing
#   the_user :reader, can_do: reading, and_cannot_do: writing
#   the_user :no_access, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :invalid, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :anonymous, can_do: reading, and_cannot_do: writing
# end
#
# describe 'Project permissions (logged in write access)' do
#   given_the_route '/projects' do
#     {
#       id: project.id
#     }
#   end
#   using_the_factory :project
#
#   the_user :admin, can_do: everything
#   the_user :owner, can_do: everything
#   the_user :writer, can_do: reading, and_cannot_do: writing
#   the_user :reader, can_do: reading, and_cannot_do: writing
#   the_user :no_access, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :invalid, can_do: nothing, and_cannot_do: everything_but_new
#   the_user :anonymous, can_do: reading, and_cannot_do: writing
# end
