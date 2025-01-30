# frozen_string_literal: true

describe 'Verification permissions' do
  create_entire_hierarchy

  given_the_route '/verifications' do
    {
      id: verification.id
    }
  end

  using_the_factory :verification, factory_args: lambda {
    #  creating a new tag to satisfy uniqueness constraint
    { audio_event_id: audio_event.id, tag_id: create(:tag).id }
  }

  let(:another_writer) {
    user_banana = create(:user, user_name: 'another_writer', skip_creation_email: true)
    create(:write_permission, creator: owner_user, user: user_banana, project:)
    user_banana
  }
  let(:another_writer_token) { Creation::Common.create_user_token(another_writer) }

  with_custom_user(:another_writer)

  for_lists_expects do |user, _action|
    case user
    when :admin
      Verification.all
    when :owner, :reader, :writer, :another_writer
      verification
    else
      []
    end
  end

  the_users :admin, can_do: everything
  the_users :reader, can_do: reading, and_cannot_do: writing
  the_user :anonymous, can_do: reading, and_cannot_do: writing, fails_with: :unauthorized
  the_user :no_access, can_do: listing, and_cannot_do: not_listing
  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
  the_user :harvester, can_do: nothing, and_cannot_do: everything

  # `writer` user SHOULD be able to DELETE (because they are the owner)
  # `writer` user SHOULD be able to PUT (update) (because they are the owner)
  the_users :writer, can_do: everything

  # `another_writer` user should NOT be able to DELETE (because they are not the owner)
  # `another_writer` user should NOT be able to PUT (update) (because they are not the owner)
  the_users :another_writer, can_do: (reading + creation)

  # `owner` user SHOULD be able to DELETE (writer user's verification), (because they are a project owner)
  # `owner` user NOT be able to PUT (update) (writer user's verification), (because they are NOT the creator)
  the_users :owner, can_do: everything_but_update
end
