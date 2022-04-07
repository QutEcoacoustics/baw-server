# frozen_string_literal: true

describe 'Harvesting a batch of files' do
  prepare_users
  prepare_project

  it 'will not allow a harvest to be created if the project does not allow uploads' do
    project.allow_audio_upload = false
    project.save!

    body = {
      harvest: {
        streaming: false
      }
    }

    post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

    expect_error(:unprocessable_entity,
      'Record could not be saved',
      { project: ['A harvest cannot be created unless its parent project has enabled audio upload'] })
  end
end
