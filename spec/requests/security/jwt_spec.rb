# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'

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

      expect_error(:unauthorized, 'Incorrect bearer format')
    end
  end
end
