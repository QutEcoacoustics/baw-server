# frozen_string_literal: true

describe 'Sites' do
  create_entire_hierarchy

  context 'for time zones' do
    it 'accepts an IANA identifier' do
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
    it 'cannot create an orphan a site' do
      body = {
        site: {
          name: 'testy test site'
        }
      }

      post '/sites', params: body, headers: api_request_headers(owner_token, send_body: true), as: :json

      expect_error(400, 'The request was not valid: Site testy test site () is not in any projects.')
    end

    # AT 2024: soft-deprecating the many to many project-site relationship
    it 'can *NOT* create an a site that belongs to multiple projects' do
      second_project = create(:project)
      body = {
        site: {
          name: 'testy test site',
          project_ids: [project.id, second_project.id]
        }
      }

      post '/sites', params: body, headers: api_request_headers(owner_token, send_body: true), as: :json

      expect_error(:unprocessable_entity, 'Record could not be saved', {
        project_ids: ['Site must belong to exactly one project']
      })
    end

    it 'update a site so that it belongs to multiple projects' do
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
            project_ids: contain_exactly(project.id, second_project.id)
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

  describe 'accidental assignment bug' do
    # https://github.com/QutEcoacoustics/baw-server/issues/679
    let(:site) { create(:site) }
    let(:another_site) { create(:site) }

    def assert_isolation
      site.reload
      another_site.reload

      aggregate_failures do
        expect(another_site.project_ids).to match([another_site.projects.first[:id]])
        expect(another_site.project_ids).not_to include(*site.projects.map(&:id))

        expect(site.projects.map(&:site_ids)).not_to include(another_site.id)
        expect(another_site.projects.map(&:site_ids)).not_to include(site.id)

        expect(site.project_ids).to match(site.projects.map(&:id))
        expect(site.project_ids).not_to include(*another_site.projects.map(&:id))
      end
    end

    before do
      Permission.new(
        user: owner_user, project: site.projects.first, level: :owner,
        creator: admin_user
      ).save!
      Permission.new(
        user: owner_user, project: another_site.projects.first, level: :owner, creator: admin_user
      ).save!

      assert_isolation
    end

    after do
      assert_isolation
    end

    it 'does not assign a site to the wrong project' do
      get "/projects/#{site.projects.first.id}/sites/#{another_site.id}", **api_headers(owner_token)

      expect_error(:not_found, 'Could not find the requested item.')
    end

    it 'does not assign a site to the wrong project (anonymous)' do
      get "/projects/#{site.projects.first.id}/sites/#{another_site.id}", **api_headers(anonymous_token)

      expect_error(:not_found, 'Could not find the requested item.')
    end

    it 'does not assign a site to the wrong project (filter)' do
      get "/projects/#{site.projects.first.id}/sites/#{another_site.id}/filter", **api_headers(owner_token)

      expect_error(:not_found, 'Could not find the requested page.')
    end

    it 'does not assign a site to the wrong project (update)' do
      body = {
        site: {
          name: 'new name'
        }
      }

      patch "/projects/#{site.projects.first.id}/sites/#{another_site.id}", params: body,
        **api_with_body_headers(owner_token)

      expect_error(:not_found, 'Could not find the requested item.')
    end

    it 'we can still create sites' do
      body = {
        site: {
          name: 'new name',
          project_ids: [site.projects.first.id]
        }
      }

      post "/projects/#{site.projects.first.id}/sites", params: body, **api_with_body_headers(owner_token)

      expect_success
    end

    it 'we can still create sites (but we cant mix ids)' do
      body = {
        site: {
          name: 'new name',
          project_ids: [another_site.projects.first.id]
        }
      }

      post "/projects/#{site.projects.first.id}/sites", params: body, **api_with_body_headers(owner_token)

      expect_error(:bad_request,
        'The request was not valid: `project_ids` must include the project id in the route parameter')
    end

    it 'we can still create sites (with just a route parameter)' do
      body = {
        site: {
          name: 'new name'
        }
      }

      post "/projects/#{site.projects.first.id}/sites", params: body, **api_with_body_headers(owner_token)

      expect_success
    end

    it 'we can still create sites (with just a body parameter)' do
      body = {
        site: {
          name: 'new name',
          project_ids: [site.projects.first.id]
        }
      }

      post '/sites', params: body, **api_with_body_headers(owner_token)

      expect_success
    end

    it 'rejects multiple project ids' do
      body = {
        site: {
          name: 'new name',
          project_ids: [site.projects.first.id, another_site.project_ids.first]
        }
      }

      post "/projects/#{site.projects.first.id}/sites", params: body, **api_with_body_headers(owner_token)

      expect_error(:unprocessable_entity, 'Record could not be saved', {
        project_ids: ['Site must belong to exactly one project']
      })
    end

    it 'fails if project id is invalid' do
      get "/projects/999999/sites/#{another_site.id}", **api_headers(owner_token)
      expect_error(:not_found, 'Could not find the requested item.')
    end

    # lastly some sanity checks

    it 'can list sites' do
      get "/projects/#{site.projects.first.id}/sites", **api_headers(owner_token)

      expect_success
    end

    it 'can show a site' do
      get "/projects/#{site.projects.first.id}/sites/#{site.id}", **api_headers(owner_token)

      expect_success
    end

    it 'can filter sites' do
      get "/projects/#{site.projects.first.id}/sites/filter", **api_headers(owner_token)

      expect_success
    end
  end
end
