# frozen_string_literal: true

describe '/projects/{project_id}/permissions' do
  create_audio_recordings_hierarchy
  it 'rejects an object that has both allow_anonymous and allow_logged_in set to true' do

    # Set up a model
    body = body_attributes_for(
      :permission,
      factory_args: {
        user_id: nil,
        level: :reader,
        allow_anonymous: true,
        allow_logged_in: true })

    # Post to the server # some random token 1
    Rails.logger.info("onwer token is #{owner_token}")
    post "/projects/#{project.id}/permissions", params: body,**api_with_body_headers(owner_token)

    # Assert the correct error is returned
    expect_json_response
    expect_error(:not_acceptable, 'You do not have sufficient permissions to access this page.', nil)

  end
end
