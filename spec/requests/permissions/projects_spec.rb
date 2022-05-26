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
    before do
      allow(Settings.permissions).to receive(:any_user_can_create_projects).and_return(false)
    end

    ensures :owner, :writer, :reader, :harvester, cannot: [:create]
  end
end

# frozen_string_literal: true

describe 'Project permissions (when modifying allow_audio_upload)' do
  create_entire_hierarchy

  given_the_route '/projects' do
    {
      id: project.id
    }
  end

  before do
    project.allow_audio_upload = false
    project.save!
  end

  context 'when updating' do
    # define a non-standard set of behaviors to test against - we don't usually send just a single property
    send_update_body do
      [{ project: { allow_audio_upload: true } }, :json]
    end

    ensures :admin, can: [:update]
    ensures :harvester, :owner, :writer, :reader, :no_access, cannot: [:update]
    ensures :anonymous, :invalid, cannot: [:update], fails_with: :unauthorized
  end

  context 'when creating' do
    # define a non-standard set of behaviors to test against - we don't usually send just a single property
    send_create_body do
      [body_attributes_for(:project, factory: :project_with_uploads_enabled), :json]
    end

    ensures :admin, can: [:create]
    ensures :harvester, :owner, :writer, :reader, :no_access, cannot: [:create]
    ensures :anonymous, :invalid, cannot: [:create], fails_with: :unauthorized
  end
end
