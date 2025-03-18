# frozen_string_literal: true

RSpec.shared_context(
  'with security context'
) do
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

  disable_cookie_jar

  before do
    reader_user.password = password
    reader_user.password_confirmation = password
    reader_user.save!

    owner_user.password = password
    owner_user.password_confirmation = password
    owner_user.save!
  end
end
