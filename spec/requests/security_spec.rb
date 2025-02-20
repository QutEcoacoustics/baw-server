# frozen_string_literal: true

describe '/security' do
  create_audio_recordings_hierarchy

  let(:password) {
    'iamsosecretyouwillforgetmewhenyoureadme'
  }

  let(:cookie_name) {
    Rails.application.config.session_options[:key]
  }

  def headers(token: nil, cookie: nil, jwt: nil, post: false)
    headers = {
      'ACCEPT' => 'application/json'
    }

    headers['CONTENT_TYPE'] = 'application/json' if post
    headers['HTTP_AUTHORIZATION'] = "Token token=\"#{token}\"" if token
    headers['HTTP_AUTHORIZATION'] = "Bearer #{jwt}" if jwt
    # the baw_session_cookie method includes the name of the cookie
    headers['Cookie'] = cookie.to_s if cookie

    headers
  end

  def parse_set_cookie
    Array(response.headers['set-cookie']).to_h { |x|
      x.split('=', 2)
    }
  end

  def baw_session_cookie
    parse_set_cookie['_baw_session']
  end

  def baw_session_cookie_value
    "_baw_session=#{baw_session_cookie.split(';').first}"
  end

  def assert_session_info_response
    expect_success

    reader_user.reload

    expect(api_data).to match(a_hash_including(
      auth_token: reader_user.authentication_token,
      user_name: reader_user.user_name
    ))

    api_data[:auth_token]
  end

  before do
    reader_user.password = password
    reader_user.password_confirmation = password
    reader_user.save!

    owner_user.password = password
    owner_user.password_confirmation = password
    owner_user.save!
  end

  describe 'authorization' do
    disable_cookie_jar

    describe 'sign in' do
      it 'can sign in (with email)' do
        body = {
          user: {
            email: reader_user.email,
            password:
          }
        }
        post '/security', params: body, headers: headers(post: true), as: :json

        assert_session_info_response

        expect(baw_session_cookie).to match(%r{.+; path=/; httponly; samesite=lax})
      end

      it 'can sign in (with login)' do
        body = {
          user: {
            login: reader_user.user_name,
            password:
          }
        }
        post '/security', params: body, headers: headers(post: true), as: :json

        assert_session_info_response

        expect(baw_session_cookie).to match(%r{.+; path=/; httponly; samesite=lax})
      end

      describe 'backwards compatibility for API calls' do
        it 'can sign in (with email)' do
          body = { email: reader_user.email, password: }
          post '/security', params: body, headers: headers(post: true), as: :json

          assert_session_info_response

          expect(baw_session_cookie).to match(%r{.+; path=/; httponly; samesite=lax})
        end

        it 'can sign in (with login)' do
          body = { login: reader_user.user_name, password: }
          post '/security', params: body, headers: headers(post: true), as: :json

          assert_session_info_response

          expect(baw_session_cookie).to match(%r{.+; path=/; httponly; samesite=lax})
        end
      end

      describe 'errors' do
        render_error_responses

        it 'errors without email and login' do
          body = {
            user: {
              password:
            }
          }
          post '/security', params: body, headers: headers(post: true), as: :json

          expect_error(:unprocessable_content,
            'The request could not be understood: param is missing or the value is empty: login')
        end

        it 'errors without password' do
          body = {
            user: {
              login: reader_user.email
            }
          }
          post '/security', params: body, headers: headers(post: true), as: :json

          expect_error(:unprocessable_content,
            'The request could not be understood: param is missing or the value is empty: password')
        end

        it 'errors without password (2)' do
          body = {
            user: {
              email: reader_user.email
            }
          }
          post '/security', params: body, headers: headers(post: true), as: :json

          expect_error(:unprocessable_content,
            'The request could not be understood: param is missing or the value is empty: password')
        end
      end
    end

    it 'can sign in and use the cookie to access a resource' do
      get "/projects/#{project.id}", headers: headers, as: :json

      expect_error(:unauthorized, 'You need to log in or register before continuing.')

      body = {
        user: {
          email: reader_user.email,
          password:
        }
      }
      post '/security', params: body, headers: headers(post: true), as: :json

      expect_success
      baw_session_cookie

      get "/projects/#{project.id}", headers: headers(cookie: baw_session_cookie_value), as: :json

      expect_success
    end

    it 'rotates auth tokens on cookie sign in' do
      body = {
        user: {
          email: reader_user.email,
          password:
        }
      }

      post '/security', params: body, headers: headers(post: true), as: :json

      expect_success

      reader_user.reload

      token = reader_user.authentication_token
      expect(token).to be_present

      post '/security', params: body, headers: headers(post: true), as: :json

      expect_success

      reader_user.reload

      new_token = reader_user.authentication_token
      expect(new_token).not_to eq token
    end

    it 'can use a cookie to get session info' do
      body = {
        user: {
          email: reader_user.email,
          password:
        }
      }

      post '/security', params: body, headers: headers(post: true), as: :json
      assert_session_info_response

      get '/security/user', headers: headers(cookie: baw_session_cookie_value), as: :json
      assert_session_info_response
    end

    describe 'signing out' do
      let(:body) {
        {
          user: {
            email: reader_user.email,
            password:
          }
        }
      }

      it '(cookie) clears the auth token on sign out' do
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success

        delete '/security', headers: headers(cookie: baw_session_cookie_value)
        expect_success

        reader_user.reload
        expect(reader_user.authentication_token).to be_nil
      end

      it '(cookie) can sign out' do
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success

        cookie = baw_session_cookie

        # NOTE: the old cookie is not invalidated, it will still work until it
        # expires. However, a new Set-Cookie header will be sent with a new
        # cookie which basically represents an anonymous session.
        delete '/security', headers: headers(cookie:)
        new_cookie = baw_session_cookie

        expect(new_cookie).not_to eq cookie

        get "/projects/#{project.id}", headers: headers(cookie: new_cookie), as: :json
        expect_error(:unauthorized, 'You need to log in or register before continuing.')
      end

      it '(token) clears the auth token on sign out' do
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success

        delete '/security', headers: headers(token: api_data[:auth_token])
        expect_success

        reader_user.reload
        expect(reader_user.authentication_token).to be_nil
      end

      it '(token) can sign out' do
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success

        delete '/security', headers: headers(token: api_data[:auth_token])
        expect_success

        get "/projects/#{project.id}", headers: headers(token: api_data[:auth_token]), as: :json
        expect_error(:unauthorized, 'You need to log in or register before continuing.')
      end

      it '(jwt) clears the auth token on sign out' do
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success

        token = Api::Jwt.encode(subject: reader_user.id)

        delete '/security', headers: headers(jwt: token)
        expect_success

        reader_user.reload
        expect(reader_user.authentication_token).to be_nil
      end

      it '(jwt) can sign out' do
        skip('jwts do support signing out')
      end
    end

    describe 'tokens' do
      before do
        body = {
          user: {
            email: reader_user.email,
            password:
          }
        }

        post '/security', params: body, headers: headers(post: true), as: :json
        @token = assert_session_info_response
      end

      it 'can get session info with a token' do
        get '/security/user', headers: headers(token: @token), as: :json

        assert_session_info_response
      end

      it 'does not cycle the auth token' do
        auth_token = reader_user.authentication_token

        logger.warn('get /security/user A', headers: headers(token: @token))
        get '/security/user', headers: headers(token: @token), as: :json
        logger.warn('response get /security/user A', headers: headers(token: @token))
        assert_session_info_response

        logger.warn('get /security/user B', headers: headers(token: @token))
        get '/security/user', headers: headers(token: @token), as: :json
        logger.warn('response get /security/user B', headers: headers(token: @token))
        assert_session_info_response

        reader_user.reload
        expect(reader_user.authentication_token).to eq auth_token
      end

      it 'checks that using a token increments the last seen at date' do
        reader_user.reload
        previous = reader_user.last_seen_at

        # we only update last_seen_at every 10 minutes or so
        Timecop.travel(601)

        get '/security/user', headers: headers(token: @token), as: :json
        assert_session_info_response

        reader_user.reload
        updated = reader_user.last_seen_at

        expect(updated).not_to eq previous
      end

      it 'can sign in and get a token to access a resource' do
        get "/projects/#{project.id}", headers: headers(token: @token), as: :json
        expect_success
      end

      it 'can access a resource by placing the token in a QSP' do
        get "/projects/#{project.id}?user_token=#{@token}", headers: headers, as: :json
        expect_success
      end

      it 'rejects nonsense' do
        @token = 'nonsense'
        get "/projects/#{project.id}", headers: headers(token: @token), as: :json

        expect_error(:unauthorized, 'Invalid authentication token')
      end

      it 'rejects an empty string' do
        @token = ''
        get "/projects/#{project.id}", headers: headers(token: @token), as: :json

        expect_error(:unauthorized, 'You need to log in or register before continuing.')
      end
    end

    describe 'JWTs' do
      before do
        body = {
          user: {
            email: reader_user.email,
            password:
          }
        }

        post '/security', params: body, headers: headers(post: true), as: :json
        assert_session_info_response

        @token = Api::Jwt.encode(subject: reader_user.id)
      end

      it 'can get session info with a JWT' do
        get '/security/user', headers: headers(jwt: @token), as: :json
        assert_session_info_response
      end

      it 'does not cycle the auth token' do
        auth_token = reader_user.authentication_token

        get '/security/user', headers: headers(jwt: @token), as: :json
        assert_session_info_response

        get '/security/user', headers: headers(jwt: @token), as: :json
        assert_session_info_response

        reader_user.reload
        expect(reader_user.authentication_token).to eq auth_token
      end

      it 'checks that using a JWT increments the last seen at date' do
        reader_user.reload
        previous = reader_user.last_seen_at

        # we only update last_seen_at every 10 minutes or so
        Timecop.travel(601)

        get '/security/user', headers: headers(jwt: @token), as: :json
        assert_session_info_response

        reader_user.reload
        updated = reader_user.last_seen_at

        expect(updated).not_to eq previous
      end

      it 'can use a JWT to access a resource' do
        get "/projects/#{project.id}", headers: headers(jwt: @token), as: :json
        expect_success
      end

      it 'does not accept a JWT that is expired' do
        @token = Api::Jwt.encode(subject: reader_user.id, expiration: -1.hour)
        Api::Jwt.decode(@token)
        get "/projects/#{project.id}", headers: headers(jwt: @token), as: :json

        expect_error(:unauthorized, 'JWT decode error: token is expired')
      end

      it 'does not accept a JWT that is that is not valid yet' do
        @token = Api::Jwt.encode(subject: reader_user.id, not_before: 1.hour)
        Api::Jwt.decode(@token)
        get "/projects/#{project.id}", headers: headers(jwt: @token), as: :json

        expect_error(:unauthorized, 'JWT decode error: token is immature')
      end

      it 'rejects nonsense' do
        @token = 'nonsense'
        get "/projects/#{project.id}", headers: headers(jwt: @token), as: :json

        expect_error(:unauthorized, 'JWT decode error')
      end

      it 'rejects an empty string' do
        @token = ''
        get "/projects/#{project.id}", headers: headers(jwt: @token), as: :json

        expect_error(:unauthorized, 'You need to log in or register before continuing.')
      end
    end
  end

  describe 'CSRF' do
    create_audio_recordings_hierarchy

    with_csrf_protection

    it 'sets the CSRF cookie' do
      # mock production so we can test secure is working
      allow(BawApp).to receive(:dev_or_test?).and_return(false)

      body = {
        user: {
          email: owner_user.email,
          password:
        }
      }
      post '/security', params: body, headers: headers(post: true).merge(
        # pretend we're using https so that the secure cookie is sent in response headers
        'X-Forwarded-Proto' => 'https'
      ), as: :json

      expect_success

      expect(parse_set_cookie['XSRF-TOKEN']).to match(%r{.+; path=/; secure; samesite=none})
    end
  end
end
