# frozen_string_literal: true

describe 'Verification permissions' do
  create_entire_hierarchy

  # Only index and show are available on the nested route
  # Index is available to all users, show is available to all users with reader
  # permissions on project
  given_the_route '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/verifications' do
    {
      audio_recording_id: audio_recording.id,
      audio_event_id: audio_event.id,
      id: verification.id
    }
  end

  using_the_factory :verification, factory_args: lambda {
    #  creating a new tag to satisfy uniqueness constraint
    { audio_event_id: audio_event.id, tag_id: create(:tag).id }
  }

  let(:another_writer) do
    create(:user, user_name: 'another_writer', skip_creation_email: true).tap do |user|
      create(:write_permission, creator: owner_user, user: user, project: project)
    end
  end

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

  the_users :admin, :reader, :writer, :another_writer, :owner,
    can_do: Set[:index, :show, :filter],
    fails_with: :not_found

  the_user :anonymous, can_do: Set[:index, :filter], fails_with: [:not_found, :unauthorized]

  the_user :invalid, can_do: nothing, fails_with: [:not_found, :unauthorized]

  the_user :no_access, can_do: Set[:index, :filter], fails_with: [:not_found, :forbidden]

  the_user :harvester, can_do: nothing, fails_with: [:not_found, :forbidden]
end

describe 'Verification permissions (shallow)' do
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
  send_update_body do
    [{
      'verification' => {
        confirmed: Verification::CONFIRMATION_FALSE
      }
    }, :json]
  end

  send_create_body do
    [{
      'verification' => {
        confirmed: Verification::CONFIRMATION_TRUE,
        audio_event_id: audio_event.id,
        tag_id: create(:tag).id
      }
    }, :json]
  end

  let(:another_writer) do
    create(:user, user_name: 'another_writer', skip_creation_email: true).tap do |user|
      create(:write_permission, creator: owner_user, user: user, project: project)
    end
  end

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

  # `writer` user SHOULD be able to DELETE (because they are the verification creator)
  # `writer` user SHOULD be able to PUT (update) (because they are the verification creator)
  the_users :admin, :writer,
    can_do: everything

  # `another_writer` user should NOT be able to DELETE (because they are not the verification creator)
  # `another_writer` user should NOT be able to PUT (update) (because they are not the verification creator)
  the_user :another_writer, can_do: (reading + creation)

  the_user :reader, can_do: reading, and_cannot_do: writing

  # `owner` user SHOULD be able to DELETE (writer user's verification), (because they are a project owner)
  # `owner` user NOT be able to PUT (update) (writer user's verification), (because they are NOT the creator)
  the_user :owner, can_do: everything_but_update

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized
  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
  the_user :no_access, can_do: listing, and_cannot_do: not_listing
  the_user :harvester, can_do: nothing, and_cannot_do: everything
end
