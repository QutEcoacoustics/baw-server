# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/media/media_access_spec.rb.

# Ported from spec/acceptance/media/media_access_spec.rb:74-130.
# Error-link bodies: forbidden is asserted in requests/media/media_ported_spec.rb,
# unauthorized in requests/errors_ported_spec.rb.
{
  basic: [:prepare_project, false, false],
  logged_in: [:prepare_project_logged_in, true, false],
  anonymous: [:prepare_project_anon, false, true],
  combined: [:prepare_project_anon_and_logged_in, true, true]
}.each do |access, (prepare, logged_in, anonymous)|
  describe "Media metadata permissions: #{access}", :aggregate_failures do
    create_audio_recordings_hierarchy(method(prepare))

    given_the_route '/audio_recordings/{audio_recording_id}/media.json' do
      { audio_recording_id: audio_recording.id }
    end

    with_idempotent_requests_only
    do_not_check_permissions_for all_users, [:show, :create, :update, :destroy, :filter, :new]

    with_custom_action :index, path: '', verb: :get, expect: lambda { |_user, _action|
      expect(api_data.dig(:recording, :channel_count)).to eq(audio_recording.channels)
    }

    ensures :admin, :owner, :writer, :reader,
      can: [:index], cannot: nothing

    # Anonymous access alone deliberately does not grant access to signed-in strangers.
    ensures :no_access,
      can: logged_in ? [:index] : nothing,
      cannot: logged_in ? nothing : [:index],
      fails_with: :forbidden

    ensures :harvester, can: nothing, cannot: [:index], fails_with: :forbidden

    # Invalid credentials must still be rejected on public projects.
    ensures :invalid, can: nothing, cannot: [:index], fails_with: :unauthorized

    ensures :anonymous,
      can: anonymous ? [:index] : nothing,
      cannot: anonymous ? nothing : [:index],
      fails_with: :unauthorized
  end
end
