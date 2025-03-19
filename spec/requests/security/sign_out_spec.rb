# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'

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
end
