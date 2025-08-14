# frozen_string_literal: true

describe '/audio_event_import_files' do
  # NOTE: most of the tests for this endpoint are included
  # in the audio_event_imports/*_spec.rb files. The two endpoints
  # are closely related and don't make sense being tested separately.

  prepare_users

  it 'has a name calculated custom field that works for a analysis result file' do
    model = create(:audio_event_import_file, :with_path)

    get "/audio_event_imports/#{model.audio_event_import.id}/files/#{model.id}",
**api_headers(admin_token)
    expect_success

    expect(api_data).to match(a_hash_including(
      name: File.basename(model.path)
    ))
  end

  it 'has a name calculated custom field that works for an uploaded file' do
    model = create(:audio_event_import_file, :with_file)

    get "/audio_event_imports/#{model.audio_event_import.id}/files/#{model.id}", **api_headers(admin_token)
    expect_success

    expect(api_data).to match(a_hash_including(
      name: model.file.filename
    ))
  end
end
