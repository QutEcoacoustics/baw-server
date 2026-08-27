# frozen_string_literal: true

describe 'reports/tag_rate' do
  create_audio_recordings_hierarchy
  let(:body) { { options: { bucket_size: :day }, filter: {} } }

  describe 'with bucket size of day' do
    it 'passes' do
      post '/reports/tag_rate', params: body, **api_headers(writer_token)
      expect_success
    end
  end
end
