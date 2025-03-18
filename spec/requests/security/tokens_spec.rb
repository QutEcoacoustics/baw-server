# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'

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

      expect_error(:unauthorized, 'Incorrect token format')
    end

    it 'rejects a token that is not wrapped in double quotes' do
      headers = {
        'ACCEPT' => 'application/json',
        'HTTP_AUTHORIZATION' => "Token token=#{@token}"
      }
      get "/projects/#{project.id}", headers: headers, as: :json

      expect_error(:unauthorized, 'Incorrect token format')
    end

    describe 'rotation' do
      it 'does not rotate auth tokens on sign in if we are before the expiration period' do
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
        expect(new_token).to eq token
      end

      it 'does not rotate the auth token after using the token to sign in' do
        auth_token = reader_user.authentication_token

        get '/security/user', headers: headers(token: @token), as: :json

        assert_session_info_response

        get '/security/user', headers: headers(token: @token), as: :json

        assert_session_info_response

        reader_user.reload
        expect(reader_user.authentication_token).to eq auth_token
      end

      it 'refuses resource access, IFF the token is expired' do
        Timecop.travel(Settings.authentication.token_rolling_expiration + 1.minute)

        get "/projects/#{project.id}", headers: headers(token: @token), as: :json
        expect_error(:unauthorized, 'Expired authentication token')

        # just checking that there is no side effect from failing to access the resource
        3.times do
          Timecop.travel(1.minute)
          get "/projects/#{project.id}", headers: headers(token: @token), as: :json
          expect_error(:unauthorized, 'Expired authentication token')
        end

        # and the expired token remains the same
        reader_user.reload
        expect(reader_user.authentication_token).to eq @token
      end

      it 'ensures a new auth token is set on sign in, IFF the token is expired' do
        Timecop.travel(Settings.authentication.token_rolling_expiration + 1.minute)

        get "/projects/#{project.id}", headers: headers(token: @token), as: :json

        expect_error(:unauthorized, 'Expired authentication token')

        # token remains the same, it just doesn't work anymore
        reader_user.reload
        expect(reader_user.authentication_token).to eq @token

        # now sign in
        body = {
          user: {
            email: reader_user.email,
            password:
          }
        }
        post '/security', params: body, headers: headers(post: true), as: :json
        new_token = assert_session_info_response

        reader_user.reload
        expect(reader_user.authentication_token).to eq new_token
        expect(reader_user.authentication_token).not_to eq @token
      end

      it 'ensures resource access by any authentication method extends the token expiration by rolling a window',
        :slow do
        # in our dev environment the cookie timeout is always less than the token timeout
        # but i'm trying to make the test resilient to changes in the configuration.
        # Also divide by 3 because we have two other auth methods that might be used
        # between the shortest method's timeout
        increment = [
          Rails.configuration.devise.timeout_in / 3,
          Settings.authentication.token_rolling_expiration / 3
        ].min

        jwt = Api::Jwt.encode(subject: reader_user.id, expiration: 1.year)
        cookie = baw_session_cookie_value

        100.times do |i|
          Timecop.travel(increment)

          case i % 3
          when 0 then headers(token: @token)
          when 1 then headers(cookie:)
          when 2 then headers(jwt:)
          end => headers

          Rails.logger.debug { "Iteration #{i}: #{headers}" }

          get "/projects/#{project.id}", headers:, as: :json

          # cookie updates every request because we disabled the cookie jar
          cookie = baw_session_cookie_value

          expect_success
        end

        # by the time we're here, we're already many times past the original expiration time
        get '/security/user', headers: headers(token: @token), as: :json
        current_token = assert_session_info_response

        expect(current_token).to eq reader_user.authentication_token
        expect(current_token).to eq @token
      end
    end
  end
end
