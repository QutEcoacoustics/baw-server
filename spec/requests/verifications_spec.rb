# frozen_string_literal: true

describe 'Verifications' do
  render_error_responses
  create_entire_hierarchy

  before do
    create(:verification, audio_event:, creator: owner_user, confirmed: Verification::CONFIRMATION_TRUE)
    create(:verification, audio_event:, creator: writer_user, confirmed: Verification::CONFIRMATION_FALSE)
  end

  let(:update_verification) {
    create(:verification, audio_event:, creator: writer_user, confirmed: Verification::CONFIRMATION_SKIP)
  }
  let(:second_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  it 'can update a verification' do
    payload = {
      verification: {
        confirmed: Verification::CONFIRMATION_UNSURE
      }
    }
    patch "/verifications/#{verification.id}",
      params: payload, **api_with_body_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect(api_data).to include(
      audio_event_id: audio_event.id,
      creator_id: writer_user.id,
      tag_id: tag.id,
      confirmed: Verification::CONFIRMATION_UNSURE
    )
  end

  it 'can upsert a verification when a matching record exists' do
    payload = {
      verification: {
        audio_event_id: update_verification.audio_event_id,
        tag_id: update_verification.tag_id,
        confirmed: Verification::CONFIRMATION_UNSURE
      }
    }

    put '/verifications',
      params: payload, **api_with_body_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect(api_data).to include(
      audio_event_id: update_verification.audio_event_id,
      creator_id: writer_user.id,
      tag_id: update_verification.tag_id,
      confirmed: Verification::CONFIRMATION_UNSURE
    )
  end

  it 'can upsert a new verification when no matching record exists' do
    payload = {
      verification: {
        audio_event_id: second_event.id,
        tag_id: tag.id,
        confirmed: Verification::CONFIRMATION_SKIP
      }
    }
    put '/verifications',
      params: payload, **api_with_body_headers(writer_token)

    expect(response).to have_http_status(201)
    expect(Verification.count).to eq(4)
    expect(api_data).to include(
      audio_event_id: second_event.id,
      creator_id: writer_user.id,
      tag_id: tag.id,
      confirmed: Verification::CONFIRMATION_SKIP
    )
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

      expect_error(:conflict, 'The item must be unique.', nil)
    end

    it 'returns conflicting ids when unique constraint is violated' do
      post '/verifications', params: payload, **api_with_body_headers(writer_token)

      error_info = { unique_violation: { audio_event_id: audio_event.id, tag_id: tag.id, creator_id: writer_user.id } }
      expect_error(:conflict, 'The item must be unique.', error_info)
    end
  end
end
