require 'rails_helper'

describe 'Sites' do
  create_entire_hierarchy

  context 'for time zones' do
    example 'accepts an IANA identifier' do
      body = {
        site: {
          name: 'test site',
          tzinfo_tz: 'Australia/Sydney'
        }
      }
      post "/projects/#{project.id}/sites", params: body, headers: api_request_headers(owner_token, send_body: true), as: :json
      expect(response).to have_http_status(:success)
      expect(api_result).to include(data: hash_including({
        timezone_information: hash_including({
          identifier: 'Australia/Sydney'
        })
      }))
    end
  end
end
