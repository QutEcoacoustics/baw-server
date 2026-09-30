#frozen_string_literal: true

describe 'AudioEvent permissions' do
  create_audio_recordings_hierarchy
  let(:audio_event) { create(:audio_event, audio_recording:, creator: owner_user) }

  given_the_route '/audio_recordings/{audio_recording_id}/audio_events' do
    {
      audio_recording_id: audio_recording.id,
      id: audio_event.id
    }
  end

  using_the_factory :audio_event, factory_args: lambda {
    { audio_recording_id: audio_recording.id }
  }

  for_lists_expects do |user, _action|
    case user
    when :admin
      AudioEvent.all
    when :owner, :reader, :writer
      audio_event
    else
      []
    end
  end

  with_custom_action(
    :stats,
    path: 'stats',
    verb: :get,
    expect: lambda { |_user, _action|
      expect(api_data).to include(
        count: a_kind_of(Integer),
        taggings_count: a_kind_of(Integer)
      )
    }
  )

  the_users :admin, :writer, :owner, can_do: everything
  the_user :reader, can_do: (reading + [:stats]), and_cannot_do: writing
  the_user :invalid, can_do: nothing, fails_with: [:not_found, :unauthorized]
  the_user :no_access, can_do: (listing + [:stats]), fails_with: :forbidden
  the_user :anonymous, can_do: (listing + [:stats]), fails_with: [:not_found, :unauthorized]

  the_user :harvester, can_do: nothing
end
