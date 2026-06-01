# frozen_string_literal: true

require(Rails.root / 'spec' / 'support' / 'shared_context' / 'rake_context')

describe 'baw:camtrap_dp:update' do
  include_context 'rake_spec_context'

  let(:profile) { BawWorkers::Export::CamtrapDp::Profile }
  let(:written_readme) { {} }
  let(:written_local_validation_profile) { {} }

  before do
    # Capture the README content without rewriting the checked-in fixture file.
    allow(File).to receive(:write) do |path, content|
      written_readme[:path] = path
      written_readme[:content] = content
    end

    # Capture the generated local profile so the example can assert the real inlined schema bodies.
    allow(profile.const_get(:LOCAL_VALIDATION_PROFILE_PATH)).to receive(:write) do |content|
      written_local_validation_profile[:content] = content
    end

    # Stub the pinned profile asset requests so Profile.download exercises its HTTP fetch logic without network access.
    profile.const_get(:ASSET_FILES).each_value do |filename|
      stub_request(:get, URI.join(profile.const_get(:SOURCE_URL), filename).to_s)
        .to_return(body: (profile.const_get(:DIRECTORY) / filename).read)
    end

    stub_request(:get, 'https://specs.frictionlessdata.io/schemas/data-package.json')
      .to_return(body: JSON.generate(data_package_schema))

    stub_request(:get, 'http://json.schemastore.org/geojson.json')
      .to_return(body: JSON.generate(schema_store_geojson_schema))

    stub_request(:get, 'https://geojson.org/schema/GeoJSON.json')
      .to_return(body: JSON.generate(geojson_schema))
  end

  around do |example|
    Timecop.freeze(generated_at)
    example.run
  ensure
    Timecop.return
  end

  let(:generated_at) { Time.utc(2026, 7, 29, 3, 50, 44) }
  let(:data_package_schema) do
    # This is not the main camtrap profile file. It is the fake JSON document returned when the
    # code follows the data-package ref inside camtrap-dp-profile-acoustic.json.
    {
      '$schema' => 'https://json-schema.org/draft/2020-12/schema',
      'title' => 'Data Package Schema',
      'type' => 'object',
      'properties' => {
        # The main camtrap profile already has refs to the data-package URL and the schemastore
        # URL. This nested ref is what makes the real code discover the third geojson.org URL.
        # If this ref changes, the test should fail because that third URL will stop appearing in
        # the README and its JSON document will stop appearing in the generated local profile.
        'spatial' => {
          '$ref' => 'https://geojson.org/schema/GeoJSON.json'
        }
      }
    }
  end
  let(:schema_store_geojson_schema) do
    # Fake JSON document returned for the schemastore ref that already exists in the main profile.
    {
      '$schema' => 'https://json-schema.org/draft/2020-12/schema',
      'title' => 'Schema Store GeoJSON',
      'type' => 'object'
    }
  end
  let(:geojson_schema) do
    # Fake JSON document returned for the nested geojson.org ref introduced above.
    {
      '$schema' => 'https://json-schema.org/draft/2020-12/schema',
      'title' => 'GeoJSON Org Schema',
      'type' => 'object'
    }
  end
  let(:expected_readme_output) do
    <<~MARKDOWN
      # CamTrap DP Bioacoustics Downloaded profile assets

      The files in this directory (including this readme) are generated with the `baw:camtrap_dp:update` rake task. Do not edit these files manually.

      Generation date: 2026-07-29 03:50:44 UTC
      Source: https://raw.githubusercontent.com/camera-traps/bioacoustics/e4b4722fb453f5ca39c39ea3c4f348e9953f0084/camtrap-dp/1.0.2/

      ---

      ## Downloaded profile assets

      - Profile: ./camtrap-dp-profile-acoustic.json
      - Deployments: ./deployments-table-schema-acoustic.json
      - Media: ./media-table-schema-acoustic.json
      - Observations: ./observations-table-schema-acoustic.json

      ## Local validation profile

      - Profile: ./camtrap-dp-profile-acoustic.local.json
      - External references inlined:
        - https://specs.frictionlessdata.io/schemas/data-package.json
        - https://geojson.org/schema/GeoJSON.json
        - http://json.schemastore.org/geojson.json
    MARKDOWN
  end

  it 'downloads the assets, builds the local validation profile, and writes the README' do
    expect { subject.invoke }.to output(expected_readme_output).to_stdout

    expect(written_readme).to eq(
      path: profile.const_get(:README_PATH),
      content: expected_readme_output
    )

    expect(written_local_validation_profile.fetch(:content)).to include('"title": "Data Package Schema"')
    expect(written_local_validation_profile.fetch(:content)).to include('"title": "GeoJSON Org Schema"')
    expect(written_local_validation_profile.fetch(:content)).to include('"title": "Schema Store GeoJSON"')
  end
end
