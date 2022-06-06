# frozen_string_literal: true

describe Project, 'capabilities' do
  create_entire_hierarchy

  given_the_route '/projects' do
    {
      id: project.id
    }
  end

  shared_context 'with allow_audio_upload' do |enabled, can_users:, cannot_users:, unsure_users:, unauthorized_users:|
    describe "allow_audio_upload for #{enabled}" do
      before do
        project.allow_audio_upload = enabled
        project.save!
      end

      has_item_capability :create_harvest,
        can_users:,
        cannot_users:,
        unsure_users:,
        unauthorized_users:
    end
  end

  include_examples 'with allow_audio_upload', false, {
    can_users: [],
    cannot_users: [:admin, :owner, :writer, :reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }

  include_examples 'with allow_audio_upload', true, {
    can_users: [:admin, :owner],
    cannot_users: [:writer, :reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }

  has_item_capability :update_allow_audio_upload,
    can_users: [:admin],
    cannot_users: [:owner, :writer, :reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
end
