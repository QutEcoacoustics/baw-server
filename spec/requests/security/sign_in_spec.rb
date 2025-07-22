# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'

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
          'The request could not be understood: param is missing or the value is empty or invalid: login')
      end

      it 'errors without password' do
        body = {
          user: {
            login: reader_user.email
          }
        }
        post '/security', params: body, headers: headers(post: true), as: :json

        expect_error(:unprocessable_content,
          'The request could not be understood: param is missing or the value is empty or invalid: password')
      end

      it 'errors without password (2)' do
        body = {
          user: {
            email: reader_user.email
          }
        }
        post '/security', params: body, headers: headers(post: true), as: :json

        expect_error(:unprocessable_content,
          'The request could not be understood: param is missing or the value is empty or invalid: password')
      end
    end
  end
end
