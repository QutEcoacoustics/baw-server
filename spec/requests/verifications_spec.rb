# frozen_string_literal: true

describe 'Verifications' do
  create_entire_hierarchy

  it 'a reader can list verifications' do
    create(:verification)
    get '/verifications', **api_headers(reader_token)
    expect(response).to have_http_status(:ok)
  end

  context 'when filtering' do
    before do
      create(:verification, creator: reader_user, confirmed: 'true')
      create(:verification, creator: reader_user, confirmed: 'false')
    end

    let(:verification_skip) { create(:verification, creator: writer_user, confirmed: 'skip') }

    it 'can filter verifications by confirmed' do
      filter = {
        filter: {
          confirmed: { eq: verification_skip.confirmed }
        }
      }
      get '/verifications/filter', params: filter, **api_headers(reader_token)

      expect(response).to have_http_status(:ok)
      expect_number_of_items(1)
      expect(api_data).to include(a_hash_including(confirmed: verification_skip.confirmed))
    end

    it 'can filter verifications by creator' do
      filter = {
        filter: {
          creator_id: { not_eq: verification_skip.creator_id }
        }
      }
      get '/verifications/filter', params: filter, **api_headers(reader_token)

      expect(response).to have_http_status(:ok)
      expect_number_of_items(2)
      expect(api_data).to include(a_hash_including(creator_id: reader_user.id))
    end
  end
end
