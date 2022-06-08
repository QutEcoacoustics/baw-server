# frozen_string_literal: true

describe 'Media#original permissions' do
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

  shared_context 'with allow_original_downloads' do |level, can_users:, cannot_users:|
    describe "allow_original_downloads for #{level || '<none>'}" do
      before do
        project.allow_original_download = level
        project.save!
      end

      given_the_route '/audio_recordings/{audio_recording_id}/original' do
        {
          audio_recording_id: audio_recording.id
        }
      end

      with_idempotent_requests_only

      original_action = {
        path: '',
        verb: :get,
        expect: lambda { |_user, _action|
                  expect(response.content_length).to eq(audio_file_mono_data_length_bytes)
                },
        action: :index
      }

      ensures(
        *can_users,
        can: [original_action],
        cannot: nothing,
        fails_with: :forbidden
      )

      ensures :no_access, *cannot_users,
        can: nothing,
        cannot: [original_action],
        fails_with: :forbidden

      ensures :invalid, :anonymous,
        can: nothing,
        cannot: [original_action],
        fails_with: :unauthorized
    end
  end

  include_examples 'with allow_original_downloads', nil, {
    can_users: [:admin, :harvester],
    cannot_users: [:owner, :writer, :reader]
  }

  include_examples 'with allow_original_downloads', :reader, {
    can_users: [:admin, :owner, :writer, :reader, :harvester],
    cannot_users: []
  }

  include_examples 'with allow_original_downloads', :writer, {
    can_users: [:admin, :owner, :writer, :harvester],
    cannot_users: [:reader]
  }

  include_examples 'with allow_original_downloads', :owner, {
    can_users: [:admin, :owner, :harvester],
    cannot_users: [:writer, :reader]
  }
end
