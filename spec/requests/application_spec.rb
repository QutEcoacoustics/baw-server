# frozen_string_literal: true

describe 'Common behaviour', { type: :request } do
  it '404 should return 404' do
    headers = {
      'Accept' => 'application/json'
    }

    get '/i_do_not_exist', params: nil, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(response.headers).not_to have_key('X-Error-Message')
    expect(response.content_type).to include('application/json')
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['meta']['error']['details']).to eq('Could not find the requested page.')
  end

  it '404 should return 404 (png)' do
    headers = {
      'Accept' => 'image/png'
    }

    get '/images/apple-touch-icon-72x72.png', params: nil, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(response.body.length).to eq 0
    expect(response.headers).not_to have_key('X-Error-Message')
  end

  describe 'filtering tests' do
    create_entire_hierarchy

    let(:test_filter) {
      '{"filter":{"id":{"gt":0}},"sorting":{"order_by":"recorded_date","direction":"desc"},"paging":{"items":25},"projection":{"include":["id","recorded_date","sites.name","site_id","canonical_file_name"]}}'
    }

    let(:test_filter_encoded) {
      #  Base64.urlsafe_encode64(test_filter)
      # Note: padding characters were removed as most encoders do not include them for base64url
      'eyJmaWx0ZXIiOnsiaWQiOnsiZ3QiOjB9fSwic29ydGluZyI6eyJvcmRlcl9ieSI6InJlY29yZGVkX2RhdGUiLCJkaXJlY3Rpb24iOiJkZXNjIn0sInBhZ2luZyI6eyJpdGVtcyI6MjV9LCJwcm9qZWN0aW9uIjp7ImluY2x1ZGUiOlsiaWQiLCJyZWNvcmRlZF9kYXRlIiwic2l0ZXMubmFtZSIsInNpdGVfaWQiLCJjYW5vbmljYWxfZmlsZV9uYW1lIl19fQ'
    }

    it 'accepts an encoded filter via a query string parameter for filter endpoints' do
      url = "/audio_recordings/filter?filter_encoded=#{test_filter_encoded}"

      get url, **api_headers(reader_token)

      expect_success
      expect_json_response
      expect_number_of_items(1)
      expect_has_projection({ include: ['id', 'recorded_date', 'sites.name', 'site_id', 'canonical_file_name'] })
      expect_has_filter({
        id: { gt: 0 }
      })
    end

    it 'accepts an encoded filter via a query string parameter for index endpoints' do
      url = "/audio_recordings?filter_encoded=#{test_filter_encoded}"

      get url, **api_headers(reader_token)

      expect_success
      expect_json_response
      expect_number_of_items(1)
      expect_has_projection({ include: ['id', 'recorded_date', 'sites.name', 'site_id', 'canonical_file_name'] })
      expect_has_filter({
        id: { gt: 0 }
      })
    end

    it 'accepts an encoded filter as part of a form multipart request for filter endpoints' do
      body = {
        filter_encoded: test_filter_encoded
      }

      post '/audio_recordings/filter', params: body, **form_multipart_headers(reader_token)

      expect_success
      expect_json_response
      expect_number_of_items(1)
      expect_has_projection({ include: ['id', 'recorded_date', 'sites.name', 'site_id', 'canonical_file_name'] })
      expect_has_filter({
        id: { gt: 0 }
      })
    end
  end
end
