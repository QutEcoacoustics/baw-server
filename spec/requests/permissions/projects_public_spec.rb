require 'rails_helper'

# refresher:
# our permission system has two options for non-user project permissions:
# 1) anonymous access (read or none)
# 2) logged in access (write, read, or none)
#
# The combination of these permissions can lead to the
# confusing case where an anonymous user can read a project
# but when they log in, they won't have access to it!

describe 'Project permissions (anonymous read, logged in none)' do
  create_entire_hierarchy

  # anonymous access: read
  # logged in access: none
  prepare_project_anon

  given_the_route '/projects' do
    {
      id: project_anon.id
    }
  end
  using_the_factory :project
  for_lists_expects do |user, _action|
    case user
    when :admin
      Project.all
    when :owner
      [project, project_anon]
    when :reader, :writer
      # they can list project they have access to, but it is not the subject of this test
      [project]
    when :anonymous
      project_anon
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, :no_access, can_do: (listing + creation), and_cannot_do: (not_listing - creation)

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: reading, and_cannot_do: writing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end

describe 'Project permissions (anonymous none, logged in read)' do
  create_entire_hierarchy

  # anonymous access: none
  # logged in access: read
  prepare_project_logged_in

  given_the_route '/projects' do
    {
      id: project_logged_in.id
    }
  end
  using_the_factory :project
  for_lists_expects do |user, _action|
    case user
    when :admin
      Project.all
    when :owner, :reader, :writer
      [project, project_logged_in]
    when :no_access
      [project_logged_in]
    when :anonymous
      []
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, :no_access, can_do: (reading + creation), and_cannot_do: mutation

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end

describe 'Project permissions (anonymous read, logged in read)' do
  create_entire_hierarchy

  # anonymous access: read
  # logged in access: read
  prepare_project_anon_and_logged_in

  given_the_route '/projects' do
    {
      id: project_anon_and_logged_in.id
    }
  end
  using_the_factory :project
  for_lists_expects do |user, _action|
    case user
    when :admin
      Project.all
    when :owner, :reader, :writer
      [project, project_anon_and_logged_in]
    when :no_access, :anonymous
      [project_anon_and_logged_in]
    else
      []
    end
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, :no_access, can_do: (reading + creation), and_cannot_do: mutation

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: reading, and_cannot_do: writing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
