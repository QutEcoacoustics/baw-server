# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/taggings_spec.rb.

describe 'Nested tagging permissions ported from acceptance' do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
  let!(:existing_tag) { create(:tag, creator: admin_user) }

  prepare_audio_events_tags

  given_the_route '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/taggings' do
    { audio_recording_id: audio_recording.id, audio_event_id: audio_event.id, id: tagging.id }
  end
  send_create_body { [{ tagging: { tag_id: existing_tag.id } }, :json] }
  for_lists_expects { |_user, _action| [tagging] }
  do_not_check_permissions_for(all_users, everything - [:index, :show, :create])

  the_users :admin, :owner, :writer, can_do: [:index, :show, :create], and_cannot_do: []
  the_user :reader, can_do: [:index, :show], and_cannot_do: [:create]
  the_users :no_access, :harvester, can_do: nothing, and_cannot_do: [:index, :show, :create]
  the_users :invalid, :anonymous, can_do: nothing, and_cannot_do: [:index, :show, :create],
    fails_with: :unauthorized
end

describe 'User tagging index permissions ported from acceptance' do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  prepare_audio_events_tags

  given_the_route '/user_accounts/{user_id}/taggings' do
    { user_id: writer_user.id }
  end
  with_idempotent_requests_only
  for_lists_expects do |user, _action|
    [:admin, :owner, :writer, :reader].include?(user) ? [tagging] : []
  end
  do_not_check_permissions_for(all_users, everything - [:index])

  the_users :admin, :owner, :writer, :reader, :no_access, can_do: [:index], and_cannot_do: []
  the_user :harvester, can_do: nothing, and_cannot_do: [:index]
  the_users :invalid, :anonymous, can_do: nothing, and_cannot_do: [:index], fails_with: :unauthorized
end
