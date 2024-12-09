# frozen_string_literal: true

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

  before do
    # i don't know why but this was true here. maybe a shared state bug with the
    # the other example groups in this file?
    project.allow_audio_upload = false
    project.save!
  end

  the_users :admin, :owner, can_do: everything
  the_users :writer, :reader, can_do: (reading + creation), and_cannot_do: (writing - creation)

  the_user :no_access, can_do: (listing + creation), and_cannot_do: (not_listing - creation)

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized

  context 'with public project creation disabled' do
    with_custom_action(
      :create_non_public_project,
      path: '',
      verb: :post,
      expect: :created,
      body: :create,
      before: lambda { |_user, _action|
        allow(Settings.permissions).to receive(:any_user_can_create_projects).and_return(false)
      }
    )

    ensures :owner, :writer, :reader, :harvester, :no_access, cannot: [:create_non_public_project]
    ensures :anonymous, :invalid, cannot: [:create_non_public_project], fails_with: :unauthorized
    ensures :admin, can: [:create_non_public_project]
  end

  context 'when modifying allow_audio_upload: when updating' do
    # define a non-standard set of behaviors to test against - we don't usually send just a single property
    with_custom_action(
      :allow_audio_upload_update,
      path: '{id}',
      verb: :put,
      expect: :single,
      body: [{ project: { allow_audio_upload: true } }, :json],
      before: lambda { |_user, _action|
        project.allow_audio_upload = false
        project.save!
      }
    )

    ensures :admin, can: [:allow_audio_upload_update]
    ensures :harvester, :owner, :writer, :reader, :no_access, cannot: [:allow_audio_upload_update]
    ensures :anonymous, :invalid, cannot: [:allow_audio_upload_update], fails_with: :unauthorized
  end

  context 'when modifying allow_audio_upload: when creating' do
    # define a non-standard set of behaviors to test against - we don't usually send just a single property
    with_custom_action(
      :allow_audio_upload_create,
      path: '',
      verb: :post,
      expect: :created,
      body: -> { [body_attributes_for(:project, factory: :project_with_uploads_enabled), :json] },
      before: lambda { |_user, _action|
        project.allow_audio_upload = false
        project.save!
      }
    )

    ensures :admin, can: [:allow_audio_upload_create]
    ensures :harvester, :owner, :writer, :reader, :no_access, cannot: [:allow_audio_upload_create]
    ensures :anonymous, :invalid, cannot: [:allow_audio_upload_create], fails_with: :unauthorized
  end
end
