# frozen_string_literal: true

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
      post "/projects/#{project.id}/sites", params: body, headers: api_request_headers(owner_token, send_body: true),
as: :json
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

  context 'with filter queries' do
    it 'can project lat and long' do
      body = {
        projection: { include: [:name, :custom_latitude, :custom_longitude, :location_obfuscated] },
        filter: { id: { eq: site.id } }
      }

      post '/sites/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)

      expect(api_data).to match([a_hash_including(
        name: site.name,
        custom_latitude: be_within(1).of(site.latitude).and(not_eq(site.latitude)),
        custom_longitude: be_within(1).of(site.longitude).and(not_eq(site.longitude)),
        location_obfuscated: true
      )])
    end

    it 'can project lat and long (does not obfuscate for owner)' do
      body = {
        projection: { include: [:name, :custom_latitude, :custom_longitude, :location_obfuscated] },
        filter: { id: { eq: site.id } }
      }

      expect(site.projects).not_to be_empty

      post '/sites/filter', params: body, **api_with_body_headers(owner_token)

      expect_success
      expect_number_of_items(1)

      expect(api_data).to match([a_hash_including(
        name: site.name,
        custom_latitude: site.latitude.to_f,
        custom_longitude: site.longitude.to_f,
        location_obfuscated: false
      )])
    end
  end
end
