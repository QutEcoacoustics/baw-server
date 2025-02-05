# frozen_string_literal: true

describe 'Verifications' do
  create_entire_hierarchy

  before do
    create(:verification, audio_event:, creator: owner_user, confirmed: 'true')
    create(:verification, audio_event:, creator: writer_user, confirmed: 'false')
  end

  it 'a reader can list verifications' do
    get '/verifications', **api_headers(reader_token)
    expect(response).to have_http_status(:ok)
    expect_at_least_one_item
  end

  it 'can filter verifications by confirmed status' do
    filter = {
      filter: {
        confirmed: { eq: 'true' }
      }
    }
    get '/verifications/filter', params: filter, **api_headers(writer_token)

    expect(response).to have_http_status(:ok)
    expect_number_of_items(2)
    expect(api_data).to include(a_hash_including(confirmed: 'true'))
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
    expect(api_data).to include(a_hash_including(creator_id: writer_user.id))
  end
end
