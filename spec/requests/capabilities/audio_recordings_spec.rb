# frozen_string_literal: true

describe AudioRecordings, 'capabilities' do
  create_entire_hierarchy

  given_the_route '/audio_recordings' do
    {
      id: audio_recording.id
    }
  end

  shared_context 'with allow_original_downloads' do |level, can_users:, cannot_users:, unsure_users:, unauthorized_users:|
    describe "allow_original_downloads for #{level || '<none>'}" do
      before do
        project.allow_original_download = level
        project.save!
      end

      has_item_capability :original_download,
        can_users: can_users,
        cannot_users: cannot_users,
        unsure_users: unsure_users,
        unauthorized_users: unauthorized_users
    end
  end

  include_examples 'with allow_original_downloads', nil, {
    can_users: [:admin],
    cannot_users: [:owner, :writer, :reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }

  include_examples 'with allow_original_downloads', :reader, {
    can_users: [:admin, :owner, :writer, :reader],
    cannot_users: [],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }

  include_examples 'with allow_original_downloads', :writer, {
    can_users: [:admin, :owner, :writer],
    cannot_users: [:reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }

  include_examples 'with allow_original_downloads', :owner, {
    can_users: [:admin, :owner],
    cannot_users: [:writer, :reader],
    unsure_users: [],
    unauthorized_users: [:no_access, :invalid, :anonymous, :harvester]
  }
end
