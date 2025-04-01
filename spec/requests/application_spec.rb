# frozen_string_literal: true

describe 'Common behaviour' do
  it '404 should return 404' do
    headers = {
      'Accept' => 'application/json'
    }

    get('/i_do_not_exist', params: nil, headers:)

    expect(response).to have_http_status(:not_found)
    expect(response.headers).not_to have_key('X-Error-Message')
    expect(response.content_type).to include('application/json')
    parsed_response = response.parsed_body
    expect(parsed_response['meta']['error']['details']).to eq('Could not find the requested page.')
  end

  it '404 should return 404 (png)' do
    headers = {
      'Accept' => 'image/png'
    }

    get('/images/apple-touch-icon-72x72.png', params: nil, headers:)

    expect(response).to have_http_status(:not_found)
    expect(response.body.length).to eq 0
    expect(response.headers).not_to have_key('X-Error-Message')
  end

  it 'can handle malformed post requests' do
    # a json value encoded in a string (malformed)
    body = "{\r\n  \"password\": \"password\",\r\n  \"email\": \"SladeAA\"\r\n}"
    post '/security', params: body,
      headers: {
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
        'Accept' => 'application/json',
        'CONTENT_LENGTH' => 56
      }

    expect(response).to have_http_status(:unsupported_media_type)
    expect(response.headers).not_to have_key('X-Error-Message')
    expect(response.content_type).to include('application/json')
    parsed_response = response.parsed_body
    expect(parsed_response['meta']['error']['details']).to eq(
      'Failed to parse the request body. Ensure that it is formed correctly and matches the content-type (application/x-www-form-urlencoded)'
    )
  end

  describe 'unpermitted parameters' do
    create_audio_recordings_hierarchy
    it 'unpermitted parameters should return a useful error message' do
      post '/projects', params: { project: { donkey: 'kong' } }, **api_with_body_headers(writer_token)

      expect_error(
        :unprocessable_entity,
        'The request could not be understood: found unpermitted parameter: :donkey'
      )
    end
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
        status: { eq: 'ready' },
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
        status: { eq: 'ready' },
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
        status: { eq: 'ready' },
        id: { gt: 0 }
      })
    end

    it 'can correctly parse complex utf-8 string' do
      # rubocop:disable
      test = 'hello À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï ܐ ܑ ܒ ܓ ܔ ܕ ܖ ܗ ܘ ܙ ܚ ܛ ܜ ܝ ܞ ܟ'
      # rubocop:enable

      filter = JSON.dump({ filter: { name: { eq: test } } })
      encoded = Base64.urlsafe_encode64(filter)

      get "/sites?filter_encoded=#{encoded}", **api_headers(reader_token)

      expect_success
      expect_json_response
      expect_number_of_items(0)
      expect_has_filter({
        name: { eq: test }
      })
    end
  end

  describe 'JWT authorization claims' do
    disable_cookie_jar

    create_audio_recordings_hierarchy

    it 'can access anything with a standard token' do
      jwt = Api::Jwt.encode(subject: reader_user.id)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_success

      get '/sites', **jwt_headers(jwt)
      expect_success
      expect_has_ids(*Site.pluck(:id))
    end

    it 'can restrict a JWT to a single resource' do
      jwt = Api::Jwt.encode(subject: reader_user.id, resource: :projects)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_success

      get '/sites', **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this resource')
    end

    it 'can restrict a JWT to a single (other) resource' do
      jwt = Api::Jwt.encode(subject: reader_user.id, resource: :sites)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this resource')

      get '/sites', **jwt_headers(jwt)
      expect_has_ids(*Site.pluck(:id))
    end

    it 'can restrict a JWT to a single action' do
      jwt = Api::Jwt.encode(subject: reader_user.id, action: :show)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_success

      get '/sites', **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this action')
    end

    it 'can restrict a JWT to a single (other) action' do
      jwt = Api::Jwt.encode(subject: reader_user.id, action: :index)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this action')

      get '/sites', **jwt_headers(jwt)
      expect_has_ids(*Site.pluck(:id))
    end

    it 'can restrict a JWT to a single resource and action' do
      jwt = Api::Jwt.encode(subject: reader_user.id, resource: :projects, action: :show)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_success

      get '/projects', **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this action')

      get '/sites', **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this resource')
    end

    it 'can restrict a JWT to a single (other) resource and action' do
      jwt = Api::Jwt.encode(subject: reader_user.id, resource: :sites, action: :index)

      get "/projects/#{project.id}", **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this resource')

      get '/sites', **jwt_headers(jwt)
      expect_has_ids(*Site.pluck(:id))

      get "/sites/#{site.id}", **jwt_headers(jwt)
      expect_error(:forbidden, 'You do not have sufficient permissions.',
        'JWT does not allow access to this action')
    end
  end
end
