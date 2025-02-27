#frozen_string_literal: true

describe 'AudioEvent permissions' do
  create_entire_hierarchy
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

  the_users :admin, :writer, :owner, can_do: everything

  the_user :reader, can_do: reading, and_cannot_do: writing

  the_user :invalid, can_do: nothing, fails_with: [:not_found, :unauthorized]

  the_user :no_access, can_do: listing, fails_with: :forbidden

  the_user :anonymous, can_do: listing, fails_with: [:not_found, :unauthorized]

  the_user :harvester, can_do: nothing
end
