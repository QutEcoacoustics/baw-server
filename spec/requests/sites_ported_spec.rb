# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/sites_spec.rb.

describe 'Sites: ported list and filter behaviour', type: :request do
  create_audio_recordings_hierarchy

  [:shallow, :nested].each do |routing|
    context "with #{routing} routes" do
      let(:collection_path) { routing == :nested ? "/projects/#{project.id}/sites" : '/sites' }

      it 'includes location fields in the anonymous new-site template' do
        get "#{collection_path}/new", **api_headers(anonymous_token)

        expect_success
        expect(api_data).to include(:longitude, :latitude)
      end

      it 'includes the legacy list fields for readers' do
        get collection_path, **api_headers(reader_token)

        expect_success
        expect_number_of_items(1)
        expect(api_data.first.keys).to include(
          :id, :name, :description, :creator_id, :updater_id, :created_at, :updated_at,
          :project_ids, :location_obfuscated, :custom_latitude, :custom_longitude,
          :timezone_information, :description_html, :image_urls
        )
        expect(api_data.first[:project_ids]).to eq([project.id])
        expect(api_data.first).not_to include(
          :obfuscated_latitude, :obfuscated_longitude, :custom_obfuscated_location
        )
      end

      [:reader, :writer].each do |user|
        it "projects id and name but retains integer project ids for #{user}" do
          body = {
            filter: { id: { in: [site.id.to_s] } },
            projection: { include: [:id, :name] }
          }

          post "#{collection_path}/filter", params: body, **api_with_body_headers(send("#{user}_token"))

          expect_success
          expect_number_of_items(1)
          expect(api_data.first).to include(id: site.id, name: site.name, project_ids: [project.id])
          expect(api_data.first).not_to have_key(:description)
          expect_has_projection(only: ['id', 'name'])
        end
      end

      it 'filters by a project association using string ids' do
        body = { filter: { 'projects.id' => { in: [project.id.to_s] } } }

        post "#{collection_path}/filter", params: body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(1)
        expect(api_data.first).to include(id: site.id, project_ids: [project.id], description: site.description)
      end

      it 'filters by an audio recording association while projecting site fields' do
        create(:site, projects: [project], region: region, creator: owner_user)
        body = {
          filter: { 'audio_recordings.id' => { eq: audio_recording.id.to_s } },
          projection: { include: [:id, :name] }
        }

        post "#{collection_path}/filter", params: body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(1)
        expect(api_data.first).to include(id: site.id, name: site.name, project_ids: [project.id])
        expect(api_data.first).not_to have_key(:description)
        expect_has_projection(only: ['id', 'name'])
      end

      it 'retains timezone information even when it is not projected' do
        sydney_site = create(
          :site, projects: [project], region: region, creator: owner_user, tzinfo_tz: 'Australia/Sydney'
        )
        body = { projection: { include: [:id, :name] } }

        post "#{collection_path}/filter", params: body, **api_with_body_headers(writer_token)

        expect_success
        expect_number_of_items(2)
        expect(api_data.pluck(:id)).to contain_exactly(site.id, sydney_site.id)
        expect(api_data).to all(include(:project_ids, :timezone_information))
        expect(api_data.find { |item| item[:id] == sydney_site.id }).to include(
          project_ids: [project.id],
          timezone_information: a_hash_including(
            identifier_alt: 'Sydney',
            identifier: 'Australia/Sydney',
            friendly_identifier: 'Australia - Sydney',
            utc_offset: a_kind_of(Numeric)
          )
        )
        api_data.each { |item| expect(item).not_to have_key(:description) }
      end
    end
  end

  it 'obfuscates nested site locations and hides internal fields for writers' do
    # Writers, like readers, no longer have access to exact coordinates.
    site.update!(latitude: -27.5, longitude: 153.0)

    get "/projects/#{project.id}/sites/#{site.id}", **api_headers(writer_token)

    expect_success
    expect(api_data).to include(
      location_obfuscated: true,
      latitude: site.obfuscated_latitude,
      longitude: site.obfuscated_longitude,
      custom_latitude: site.obfuscated_latitude,
      custom_longitude: site.obfuscated_longitude
    )
    expect(api_data[:latitude]).not_to eq(site.latitude)
    expect(api_data[:longitude]).not_to eq(site.longitude)
    expect(api_data).not_to include(:obfuscated_latitude, :obfuscated_longitude, :custom_obfuscated_location)
  end
end
