require 'rails_helper'

describe 'Users' do
  create_entire_hierarchy

  context 'for time zones' do
    example 'accepts an IANA identifier' do
      body = {
        user: {
          tzinfo_tz: 'Australia/Sydney'
        }
      }
      # using admin user because currently that is the only user allowed to update user profiles
      patch "/user_accounts/#{admin_user.id}", params: body, headers: api_request_headers(admin_token, send_body: true), as: :json
      expect(response).to have_http_status(:success)
      expect(api_result).to include(data: hash_including({
        timezone_information: hash_including({
          identifier: 'Australia/Sydney'
        })
      }))
    end
  end
end
