# frozen_string_literal: true

describe 'AudioEventImportFile permissions' do
  create_entire_hierarchy
  ignore_pending_jobs
  let!(:audio_event_import) { create(:audio_event_import) }
  let(:request_accept) {
    'multipart/form-data'
  }
  let!(:audio_event_import_file) {
    create(:audio_event_import_file, :with_file, audio_event_import:)
  }
  let(:creator_token) {
    Creation::Common.create_user_token(audio_event_import.creator)
  }

  before do
    Permission.new(
      project_id: project.id,
      user_id: audio_event_import.creator.id,
      level: 'writer',
      creator_id: audio_event_import.creator.id
    ).save!
  end

  with_custom_user :creator
  given_the_route '/audio_event_imports/{audio_event_import_id}/files' do
    {
      audio_event_import_id: audio_event_import.id,
      id: audio_event_import_file.id
    }
  end

  send_create_body do
    f = temp_file(basename: 'generic_example.csv')
    f.write <<~CSV
      audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
      #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
    CSV

    {
      audio_event_import_file: {
        file: with_file(f),
        additional_tag_ids: []
      },
      commit: true
    }
  end

  send_update_body do
    # we don't support updates but we need to complete the dsl
    nil
  end

  for_lists_expects do |user, _action|
    case user
    when :admin, :creator
      AudioEventImportFile.where(audio_event_import:).all
    else
      []
    end
  end

  # these permissions are special, they're scoped to the user.

  the_users :admin, :creator, can_do: everything_but_update, and_cannot_do: []

  # update not allowed because the record is immutable
  ensures(*all_users, cannot: :update, fails_with: [:not_found])

  # only the creator can access the file
  the_users :owner, :writer, :reader, :no_access,
    can_do: listing,
    and_cannot_do: mutation - [:update] + [:show] + creation

  the_user :harvester, can_do: nothing, and_cannot_do: everything_but_update

  the_user :anonymous, can_do: listing, and_cannot_do: not_listing - [:update], fails_with: :unauthorized

  the_user :invalid, can_do: nothing, and_cannot_do: everything_but_update, fails_with: :unauthorized
end
