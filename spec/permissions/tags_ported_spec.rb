# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/tags_spec.rb.

describe 'Tag permissions ported from acceptance' do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  prepare_audio_events_tags

  given_the_route '/tags' do
    {
      id: tag.id,
      audio_recording_id: audio_recording.id,
      audio_event_id: audio_event.id
    }
  end
  send_create_body { [{ tag: attributes_for(:tag) }, :json] }
  for_lists_expects { |_user, _action| [tag] }

  # The legacy shallow index sent these parameters as a query, not a global tag list.
  with_custom_action :index,
    path: '?audio_recording_id={audio_recording_id}&audio_event_id={audio_event_id}',
    verb: :get, expect: :list

  # Tags have no update or destroy API routes.
  do_not_check_permissions_for(all_users, [:update, :destroy])

  the_users :admin, :owner, :writer, :reader,
    can_do: [:index, :show, :new, :create, :filter], and_cannot_do: []
  the_user :no_access, can_do: [:show, :new, :create, :filter], and_cannot_do: [:index]
  the_user :harvester, can_do: nothing, and_cannot_do: [:index, :show, :new, :create, :filter]
  the_user :invalid, can_do: nothing, and_cannot_do: [:index, :show, :new, :create, :filter],
    fails_with: :unauthorized
  the_user :anonymous, can_do: [:show, :filter], and_cannot_do: [:index, :new, :create],
    fails_with: :unauthorized
end

describe 'Nested tag index permissions ported from acceptance' do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  prepare_audio_events_tags

  given_the_route '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/tags' do
    { audio_recording_id: audio_recording.id, audio_event_id: audio_event.id }
  end
  with_idempotent_requests_only
  for_lists_expects { |_user, _action| [tag] }
  do_not_check_permissions_for(all_users, everything - [:index])

  the_users :admin, :owner, :writer, :reader, can_do: [:index], and_cannot_do: []
  the_users :no_access, :harvester, can_do: nothing, and_cannot_do: [:index]
  the_users :invalid, :anonymous, can_do: nothing, and_cannot_do: [:index], fails_with: :unauthorized
end
