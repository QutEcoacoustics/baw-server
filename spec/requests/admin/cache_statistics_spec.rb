# frozen_string_literal: true

describe 'Admin::CacheStatistics' do
  prepare_users

  let!(:audio_stats) {
    create(:cache_statistics, name: 'audio', size_bytes: 1_000_000, item_count: 50, generated_at: 1.hour.ago)
  }
  let!(:spectrogram_stats) {
    create(:cache_statistics, name: 'spectrogram', size_bytes: 2_000_000, item_count: 100, generated_at: 2.hours.ago)
  }

  describe 'GET /admin/cache_statistics' do
    it 'returns all cache statistics for admin' do
      get '/admin/cache_statistics', **api_headers(admin_token)

      expect_success
      expect(api_data).to a_collection_including(
        a_hash_including(name: 'audio', size_bytes: 1_000_000, item_count: 50),
        a_hash_including(name: 'spectrogram', size_bytes: 2_000_000, item_count: 100)
      )
    end

    it 'returns 401 for anonymous users' do
      get '/admin/cache_statistics'

      expect_error(401, 'Unauthorized')
    end

    it 'returns 403 for non-admin users' do
      get '/admin/cache_statistics', **api_headers(reader_token)

      expect_error(403, 'Forbidden')
    end
  end

  describe 'GET /admin/cache_statistics/:id' do
    it 'returns a specific cache statistic for admin' do
      get "/admin/cache_statistics/#{audio_stats.id}", **api_headers(admin_token)

      expect_success
      expect(api_data).to include(
        id: audio_stats.id,
        name: 'audio',
        size_bytes: 1_000_000,
        item_count: 50
      )
    end

    it 'returns 401 for anonymous users' do
      get "/admin/cache_statistics/#{audio_stats.id}"

      expect_error(401, 'Unauthorized')
    end

    it 'returns 403 for non-admin users' do
      get "/admin/cache_statistics/#{audio_stats.id}", **api_headers(reader_token)

      expect_error(403, 'Forbidden')
    end

    it 'returns 404 for non-existent id' do
      get '/admin/cache_statistics/999999', **api_headers(admin_token)

      expect_error(404, 'Not Found')
    end
  end

  describe 'GET /admin/cache_statistics/filter' do
    it 'supports filtering by name' do
      post '/admin/cache_statistics/filter',
        params: { filter: { name: { eq: 'audio' } } },
        **api_with_body_headers(admin_token)

      expect_success
      expect(api_data).to a_collection_including(
        a_hash_including(name: 'audio')
      )
      expect(api_data).not_to a_collection_including(
        a_hash_including(name: 'spectrogram')
      )
    end
  end
end
