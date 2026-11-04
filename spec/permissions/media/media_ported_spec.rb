# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/media/media_spec.rb.

# The five reader cases from media_spec.rb:752-859 are retained within complete
# modern permission matrices. A reference event can grant access without project access.
# The forbidden error-link body is asserted once in requests/media/media_ported_spec.rb.
[
  [:readable, false, false, 4, 7, 5, 6, [:admin, :owner, :writer, :reader]],
  [:reference, true, true, 4, 7, 5, 6, [:admin, :harvester, :owner, :writer, :reader, :no_access, :anonymous]],
  [:padding, false, false, 120, 150, 5, 6, []],
  [:non_reference, true, false, 20, 23, 21, 22, [:admin]],
  [:unrelated, true, true, 10, 13, 11, 12, []]
].each do |scenario, private_recording, reference, start_offset, end_offset, event_start, event_end, allowed|
  describe "Media event permissions: #{scenario}", :aggregate_failures do
    create_audio_recordings_hierarchy

    let(:private_creator) { create(:user) }
    let(:private_project) { create(:project, creator: private_creator) }
    let(:private_site) { create(:site, creator: private_creator, region: nil, projects: [private_project]) }
    let(:event_recording) {
      if private_recording
        create(:audio_recording, creator: private_creator, uploader: private_creator, site: private_site)
      else
        audio_recording
      end
    }
    let!(:event) {
      create(:audio_event, creator: event_recording.creator, audio_recording: event_recording,
        start_time_seconds: event_start, end_time_seconds: event_end, is_reference: reference)
    }
    let(:requested_event) {
      if scenario == :unrelated
        create(:audio_event, creator: owner_user, audio_recording:,
          start_time_seconds: event_start, end_time_seconds: event_end, is_reference: true)
      else
        event
      end
    }

    given_the_route '/audio_recordings/{audio_recording_id}' do
      {
        audio_recording_id: event_recording.id,
        event_id: requested_event.id,
        start_offset:,
        end_offset:
      }
    end

    with_idempotent_requests_only
    do_not_check_permissions_for all_users, [:show, :create, :update, :destroy, :filter, :new]
    with_custom_action :index,
      path: 'media.json?audio_event_id={event_id}&start_offset={start_offset}&end_offset={end_offset}',
      verb: :get,
      expect: lambda { |_user, _action|
        expect(Time.zone.parse(api_data.dig(:recording, :recorded_date))).to eq(event_recording.recorded_date)
      }

    ensures(*allowed, can: [:index], cannot: nothing)
    ensures(*(all_users - allowed - [:invalid, :anonymous]),
      can: nothing, cannot: [:index], fails_with: :forbidden)
    ensures :invalid, can: nothing, cannot: [:index], fails_with: :unauthorized
    ensures :anonymous, can: nothing, cannot: [:index], fails_with: :unauthorized unless allowed.include?(:anonymous)
  end
end
