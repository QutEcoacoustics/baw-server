# frozen_string_literal: true

describe 'AudioEventImport permissions' do
  create_entire_hierarchy

  let!(:audio_event_import) { create(:audio_event_import) }

  let(:creator_token) {
    Creation::Common.create_user_token(audio_event_import.creator)
  }

  given_the_route '/audio_event_imports' do
    {
      id: audio_event_import.id
    }
  end
  using_the_factory :audio_event_import
  for_lists_expects do |user, _action|
    case user
    when :admin
      AudioEventImport.all
    when :creator
      AudioEventImport.created_by(audio_event_import.creator)
    else
      []
    end
  end

  # these permissions are special, they're scoped to the user.

  the_users :admin, :creator, can_do: everything

  # they can't access an instance created by someone else, but can create a new instance.
  # testing all our standard users is basically testing project permissions have no effect on this endpoint.
  the_users :owner, :writer, :reader, :no_access,
    can_do: listing + creation,
    and_cannot_do: mutation + [:show]

  the_user :harvester, can_do: nothing, and_cannot_do: everything

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing, fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything, fails_with: :unauthorized
end
