# frozen_string_literal: true

require_relative 'security_context'

describe 'authorization' do
  include_context 'with security context'
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
