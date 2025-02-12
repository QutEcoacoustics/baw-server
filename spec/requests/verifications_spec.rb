# frozen_string_literal: true

describe 'Verifications' do
  render_error_responses
  create_entire_hierarchy

  before do
    create(:verification, audio_event:, creator: owner_user, confirmed: Verification::CONFIRMATION_TRUE)
    create(:verification, audio_event:, creator: writer_user, confirmed: Verification::CONFIRMATION_FALSE)
  end

  it 'can filter verifications by confirmed status' do
    filter = {
      filter: {
        confirmed: { eq: Verification::CONFIRMATION_TRUE }
      }
    }
    get '/verifications/filter', params: filter, **api_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect_number_of_items(2)
    expect(api_data).to include(a_hash_including(confirmed: Verification::CONFIRMATION_TRUE))
  end

  it 'can filter verifications by creator' do
    filter = {
      filter: {
        creator_id: { not_eq: owner_user.id }
      }
    }
    get '/verifications/filter', params: filter, **api_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect_number_of_items(2)
    expect(api_data).to contain_exactly(
      a_hash_including(creator_id: writer_user.id),
      a_hash_including(creator_id: writer_user.id)
    )
  end

  it 'can filter verification by audio recording' do
    filter = {
      filter: {
        'audio_recordings.id': { eq: audio_recording.id }
      }
    }
    get '/verifications/filter', params: filter, **api_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect_number_of_items(3)
  end

  describe 'invalid requests' do
    let(:payload) {
      {
        verification: {
          tag_id: tag.id,
          audio_event_id: audio_event.id,
          confirmed: Verification::CONFIRMATION_TRUE
        }
      }
    }

    it 'cannot create a duplicate verification' do
      post '/verifications', params: payload, **api_with_body_headers(writer_token)

      expect(response).to have_http_status(409)
      expect_error(:conflict, 'The item must be unique.', nil)
    end
  end
end
