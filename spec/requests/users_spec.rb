# frozen_string_literal: true

describe 'Users' do
  create_entire_hierarchy

  context 'for time zones' do
    it 'accepts an IANA identifier' do
      body = {
        user: {
          tzinfo_tz: 'Australia/Sydney'
        }
      }
      # using admin user because currently that is the only user allowed to update user profiles
      patch "/user_accounts/#{admin_user.id}", params: body,
        headers: api_request_headers(admin_token, send_body: true), as: :json
      expect(response).to have_http_status(:success)
      expect(api_result).to include(data: hash_including({
        timezone_information: hash_including({
          identifier: 'Australia/Sydney'
        })
      }))
    end
  end

  it 'when shown, returns a contactable field' do
    reader_user.contactable_yes!

    get "/user_accounts/#{reader_user.id}", **api_headers(reader_token)

    expect_success
    expect(api_data).to include(contactable: User::CONSENT_YES)
  end

  it 'accepts a contactable field' do
    body = {
      user: {
        contactable: 'yes'
      }
    }

    patch "/user_accounts/#{reader_user.id}", params: body, **api_with_body_headers(reader_token)

    expect_success
    expect(reader_user.reload.contactable_yes?).to be true
  end

  it 'rejects an invalid contactable field' do
    body = {
      user: {
        contactable: 'cucumber'
      }
    }

    patch "/user_accounts/#{reader_user.id}", params: body, **api_with_body_headers(reader_token)

    expect_error(:unprocessable_content, 'Record could not be saved', { contactable: ['is not included in the list'] })
  end

  it 'accessing my_account returns a contactable field' do
    reader_user.contactable_no!

    get '/my_account', **api_headers(reader_token)

    expect_success
    expect(api_data).to include(contactable: User::CONSENT_NO)
  end
end
