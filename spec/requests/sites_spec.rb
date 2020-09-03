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

  context 'project associations' do
    example 'cannot create an orphan a site' do
      body = {
        site: {
          name: 'testy test site'
        }
      }

      post '/sites', params: body, headers: api_request_headers(owner_token, send_body: true), as: :json

      expect_error(400, 'Site testy test site () is not in any projects.')
    end

    example 'can create an a site that belongs to multiple projects' do
      second_project = create(:project)
      body = {
        site: {
          name: 'testy test site',
          project_ids: [project.id, second_project.id]
        }
      }

      post '/sites', params: body, headers: api_request_headers(owner_token, send_body: true), as: :json

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(api_result).to include({
          data: hash_including({
            project_ids: match_array([project.id, second_project.id])
          })
        })
      end
    end

    example 'update a site so that it belongs to multiple projects' do
      second_project = create(:project)
      body = {
        site: {
          project_ids: [project.id, second_project.id]
        }
      }

      patch "/sites/#{site.id}", params: body, headers: api_request_headers(owner_token, send_body: true), as: :json

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(api_result).to include({
          data: hash_including({
            project_ids: match_array([project.id, second_project.id])
          })
        })
      end
    end
  end
end
