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

  context 'with locations' do
    describe 'location fields in API response' do
      it 'renders all location fields by default for readers' do
        get "/sites/#{site.id}", **api_headers(reader_token)

        expect_success
        expect(api_data).to match a_hash_including(
          latitude: site.obfuscated_latitude,
          longitude: site.obfuscated_longitude,
          location_obfuscated: true,
          # backwards compatibility
          custom_latitude: site.obfuscated_latitude,
          custom_longitude: site.obfuscated_longitude
        )

        # These internal columns should not be exposed in the API for non-owner users
        expect(api_data).not_to include(:obfuscated_latitude, :obfuscated_longitude, :custom_obfuscated_location)
      end

      ['admin', 'owner'].each do |user|
        it "shows the real coordinates to the #{user} user" do
          get "/sites/#{site.id}", **api_headers(send("#{user}_token"))

          expect_success

          expect(api_data).to match a_hash_including(
            latitude: site.latitude,
            longitude: site.longitude,
            location_obfuscated: false,
            obfuscated_latitude: site.obfuscated_latitude,
            obfuscated_longitude: site.obfuscated_longitude,
            custom_obfuscated_location: false,
            # backwards compatibility
            custom_latitude: site.latitude,
            custom_longitude: site.longitude
          )
        end
      end
    end

    context 'when projecting' do
      it 'can project lat and long (obfuscates for reader)' do
        body = {
          projection: {
            only: [:name, :latitude, :longitude, :custom_latitude, :custom_longitude, :location_obfuscated]
          },
          filter: { id: { eq: site.id } }
        }

        post '/sites/filter', params: body, **api_with_body_headers(reader_token)

        expect_success
        expect_number_of_items(1)

        expect(api_data).to match([a_hash_including(
          name: site.name,
          latitude: site.obfuscated_latitude,
          longitude: site.obfuscated_longitude,
          # backwards compatibility
          custom_latitude: site.obfuscated_latitude,
          custom_longitude: site.obfuscated_longitude,
          location_obfuscated: true
        )])
      end

      it 'can project lat and long (obfuscates for writer)' do
        body = {
          projection: {
            only: [:name, :latitude, :longitude, :custom_latitude, :custom_longitude, :location_obfuscated]
          },
          filter: { id: { eq: site.id } }
        }

        post '/sites/filter', params: body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(1)

        expect(api_data).to match([a_hash_including(
          name: site.name,
          latitude: site.obfuscated_latitude,
          longitude: site.obfuscated_longitude,
          # backwards compatibility
          custom_latitude: site.obfuscated_latitude,
          custom_longitude: site.obfuscated_longitude,
          location_obfuscated: true
        )])
      end

      it 'can project lat and long (does not obfuscate for owner)' do
        body = {
          projection: {
            only: [:name, :latitude, :longitude, :custom_latitude, :custom_longitude, :location_obfuscated]
          },
          filter: { id: { eq: site.id } }
        }

        expect(site.projects).not_to be_empty

        post '/sites/filter', params: body, **api_with_body_headers(owner_token)

        expect_success
        expect_number_of_items(1)

        expect(api_data).to match([a_hash_including(
          name: site.name,
          latitude: site.latitude,
          longitude: site.longitude,
          # backwards compatibility
          custom_latitude: site.latitude.to_f,
          custom_longitude: site.longitude.to_f,
          location_obfuscated: false
        )])
      end
    end

    context 'when filtering' do
      before do
        site.update!(
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: -80,
          obfuscated_longitude: 120,
          custom_obfuscated_location: true
        )
      end

      def bounding_box_query(lat_min, lat_max, long_min, long_max)
        {
          filter: {
            and: [
              { latitude: { gt: lat_min } },
              { latitude: { lt: lat_max } },
              { longitude: { gt: long_min } },
              { longitude: { lt: long_max } }
            ]
          }
        }
      end

      it 'uses obfuscated coordinates for readers (with matching bounding box)' do
        body = bounding_box_query(-81, -79, 119, 121)

        post '/sites/filter', params: body, **api_with_body_headers(reader_token)

        expect_success
        expect_number_of_items(1)
        expect(api_data.first[:id]).to eq(site.id)
      end

      it 'does not return site for readers (with non-matching bounding box)' do
        # these are the real coordinates, so should not match
        body = bounding_box_query(-28, -27, 152, 154)

        post '/sites/filter', params: body, **api_with_body_headers(reader_token)

        expect_success
        expect_number_of_items(0)
      end

      it 'uses real coordinates for owners' do
        body = bounding_box_query(-28, -27, 152, 154)

        post '/sites/filter', params: body, **api_with_body_headers(owner_token)

        expect_success
        expect_number_of_items(1)
        expect(api_data.first[:id]).to eq(site.id)
      end

      it 'does not return site for owners (with non-matching bounding box)' do
        # these are the obfuscated coordinates, so should not match
        body = bounding_box_query(-81, -79, 119, 121)

        post '/sites/filter', params: body, **api_with_body_headers(owner_token)

        expect_success
        expect_number_of_items(0)
      end
    end

    context 'when updating locations' do
      before do
        site.update!(
          latitude: -27.5,
          longitude: 153.0
        )
      end

      it 'allows owners to update site locations' do
        params = {
          site: {
            latitude: -30.0,
            longitude: 150.0
          }
        }

        patch "/sites/#{site.id}", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          latitude: -30.0,
          longitude: 150.0,
          obfuscated_latitude: not_eq(-30.0).and(be_within(Site::JITTER_RANGE).of(-30.0)),
          obfuscated_longitude: not_eq(150.0).and(be_within(Site::JITTER_RANGE).of(150.0))
        ))
      end

      it 'allows owners to set custom obfuscated locations' do
        params = {
          site: {
            custom_obfuscated_location: true,
            obfuscated_latitude: -45.0,
            obfuscated_longitude: 100.0
          }
        }

        patch "/sites/#{site.id}", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: -45.0,
          obfuscated_longitude: 100.0,
          custom_obfuscated_location: true
        ))

        site.reload
        expect(site.custom_obfuscated_location).to be true
      end

      it 'allows owners to set custom obfuscated locations (that are nil)' do
        params = {
          site: {
            custom_obfuscated_location: true,
            obfuscated_latitude: nil,
            obfuscated_longitude: nil
          }
        }

        patch "/sites/#{site.id}", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: nil,
          obfuscated_longitude: nil,
          custom_obfuscated_location: true
        ))

        site.reload
        expect(site.custom_obfuscated_location).to be true
      end

      it 'does not update custom obfuscated locations when updating lat/long when using custom obfuscated locations' do
        site.update!(
          obfuscated_latitude: -40.0,
          obfuscated_longitude: 110.0,
          custom_obfuscated_location: true
        )

        params = {
          site: {
            latitude: -30.0,
            longitude: 150.0
          }
        }

        patch "/sites/#{site.id}", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          latitude: -30.0,
          longitude: 150.0,
          obfuscated_latitude: -40.0,
          obfuscated_longitude: 110.0,
          custom_obfuscated_location: true
        ))

        site.reload
        expect(site.custom_obfuscated_location).to be true
      end

      it 'can undo custom obfuscated locations' do
        # first set a custom location
        site.update!(
          custom_obfuscated_location: true
        )

        params = {
          site: {
            custom_obfuscated_location: false
          }
        }

        patch "/sites/#{site.id}", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: not_eq(-45.0).and(be_within(Site::JITTER_RANGE).of(-27.5)),
          obfuscated_longitude: not_eq(100.0).and(be_within(Site::JITTER_RANGE).of(153.0))
        ))

        site.reload
        expect(site.custom_obfuscated_location).to be false
      end
    end

    context 'when creating sites with custom obfuscated locations' do
      it 'allows owners to create a site with custom obfuscated location' do
        params = {
          site: {
            name: 'site with custom obfuscation',
            latitude: -27.5,
            longitude: 153.0,
            custom_obfuscated_location: true,
            obfuscated_latitude: -45.0,
            obfuscated_longitude: 100.0
          }
        }

        post "/projects/#{project.id}/sites", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          name: 'site with custom obfuscation',
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: -45.0,
          obfuscated_longitude: 100.0,
          custom_obfuscated_location: true
        ))

        created_site = Site.find(api_data[:id])
        expect(created_site.custom_obfuscated_location).to be true
        expect(created_site.obfuscated_latitude).to eq(-45.0)
        expect(created_site.obfuscated_longitude).to eq(100.0)
      end

      it 'allows owners to create a site with custom obfuscated location set to nil' do
        params = {
          site: {
            name: 'site with nil obfuscation',
            latitude: -27.5,
            longitude: 153.0,
            custom_obfuscated_location: true,
            obfuscated_latitude: nil,
            obfuscated_longitude: nil
          }
        }

        post "/projects/#{project.id}/sites", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          name: 'site with nil obfuscation',
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: nil,
          obfuscated_longitude: nil,
          custom_obfuscated_location: true
        ))

        created_site = Site.find(api_data[:id])
        expect(created_site.custom_obfuscated_location).to be true
        expect(created_site.obfuscated_latitude).to be_nil
        expect(created_site.obfuscated_longitude).to be_nil
      end

      it 'auto-generates obfuscated location when custom_obfuscated_location is false' do
        params = {
          site: {
            name: 'site with auto obfuscation',
            latitude: -27.5,
            longitude: 153.0
          }
        }

        post "/projects/#{project.id}/sites", params:, **api_with_body_headers(owner_token)

        expect_success

        expect(api_data).to match(a_hash_including(
          name: 'site with auto obfuscation',
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: not_eq(-27.5).and(be_within(Site::JITTER_RANGE).of(-27.5)),
          obfuscated_longitude: not_eq(153.0).and(be_within(Site::JITTER_RANGE).of(153.0)),
          custom_obfuscated_location: false
        ))
      end

      it 'ignores obfuscated_latitude/longitude when custom_obfuscated_location is false' do
        params = {
          site: {
            name: 'site ignoring custom values',
            latitude: -27.5,
            longitude: 153.0,
            custom_obfuscated_location: false,
            obfuscated_latitude: -45.0,
            obfuscated_longitude: 100.0
          }
        }

        post "/projects/#{project.id}/sites", params:, **api_with_body_headers(owner_token)

        expect_success

        # obfuscated values should be auto-generated, not the ones we provided
        expect(api_data).to match(a_hash_including(
          name: 'site ignoring custom values',
          latitude: -27.5,
          longitude: 153.0,
          obfuscated_latitude: not_eq(-45.0).and(be_within(Site::JITTER_RANGE).of(-27.5)),
          obfuscated_longitude: not_eq(100.0).and(be_within(Site::JITTER_RANGE).of(153.0)),
          custom_obfuscated_location: false
        ))
      end
    end
  end
end
