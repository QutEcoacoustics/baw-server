# frozen_string_literal: true

shared_context 'with allow_original_downloads' do |level, can_users:, cannot_users:|
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  let!(:test_file) {
    link_original_audio(
      target: Fixtures.audio_file_mono,
      uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date,
      original_format: 'mp3'
    )
  }

  after do
    test_file.unlink
  end

  describe "allow_original_downloads for #{level || '<none>'}" do
    before do
      project.allow_original_download = level
      project.save!
    end

    given_the_route '/audio_recordings/{audio_recording_id}/original' do
      {
        audio_recording_id: audio_recording.id,
        id: audio_recording.id
      }
    end

    with_idempotent_requests_only

    with_custom_action(:index, path: '', verb: :get, expect: lambda { |_user, _action|
      expect(response.content_length).to eq(audio_file_mono_data_length_bytes)
    })

    ensures(
      *can_users,
      can: [:index],
      cannot: nothing,
      fails_with: :forbidden
    )

    ensures :no_access, *cannot_users,
      can: nothing,
      cannot: [:index],
      fails_with: :forbidden

    ensures :invalid, :anonymous,
      can: nothing,
      cannot: [:index],
      fails_with: :unauthorized

    ensures(
      *(can_users + cannot_users + [:no_access, :invalid, :anonymous]),
      can: nothing,
      cannot: [:show, :create, :update, :destroy, :filter, :new],
      fails_with: :not_found
    )
  end
end

describe 'Media#original permissions' do
  include_examples 'with allow_original_downloads', nil, {
    can_users: [:admin, :harvester],
    cannot_users: [:owner, :writer, :reader]
  }
end

describe 'Media#original permissions' do
  include_examples 'with allow_original_downloads', :reader, {
    can_users: [:admin, :owner, :writer, :reader, :harvester],
    cannot_users: []
  }
end

describe 'Media#original permissions' do
  include_examples 'with allow_original_downloads', :writer, {
    can_users: [:admin, :owner, :writer, :harvester],
    cannot_users: [:reader]
  }
end

describe 'Media#original permissions' do
  include_examples 'with allow_original_downloads', :owner, {
    can_users: [:admin, :owner, :harvester],
    cannot_users: [:writer, :reader]
  }
end
