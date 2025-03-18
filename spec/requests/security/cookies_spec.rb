# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'

  describe 'cookies' do
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
  end
end
