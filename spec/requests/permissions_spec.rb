# frozen_string_literal: true

describe '/projects/{project_id}/permissions' do
  create_audio_recordings_hierarchy
  it 'rejects an object that has both allow_anonymous and allow_logged_in set to true' do
    # a permissions row can have one of three mutually exclusive subjects:
    # - a user
    # - any logged in user
    # - any guest user
    # this test tests that the exclusive fields cannot be set at the same time.

    body = body_attributes_for(
      :permission,
      factory_args: {
        user_id: nil,
        level: :reader,
        allow_anonymous: true,
        allow_logged_in: true
      }
    )

    # Post to the server # some random token 1
    Rails.logger.info("owner token is #{owner_token}, #{owner_user.authentication_token}")
    post "/projects/#{project.id}/permissions", params: body, **api_with_body_headers(owner_token)

    # Assert the correct error is returned
    expect_json_response
    expect_error(:unprocessable_entity, 'Record could not be saved', {
      allow_logged_in: ['is not exclusive: logged in users is true, anonymous users is true, '],
      allow_anonymous: ['is not exclusive: logged in users is true, anonymous users is true, ']
    })
  end
end
