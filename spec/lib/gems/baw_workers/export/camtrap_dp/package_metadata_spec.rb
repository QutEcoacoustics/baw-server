# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::PackageMetadata do
  create_audio_recordings_hierarchy

  subject(:descriptor) do
    BawWorkers::Export::CamtrapDp::PackageMetadata.build(deployments:, scientific_names:, options:).as_json
  end

  let(:options) do
    BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
      user: nil,
      should_obfuscate: false,
      contributors: [{ title: 'Alice', path: 'http://www.test' }],
      project_capture_method: ['continuous'],
      project_sampling_design: 'systematicRandom',
      package_title: 'Test Package',
      emit_project_license: true,
      forced_timezone: nil
    )
  end
  let(:scientific_names) { ['Xema sabini', 'Amytornis striatus'] }
  let(:deployment) do
    BawWorkers::Export::CamtrapDp::DeploymentAccumulator::Deployment.new(
      site:,
      start: Time.utc(2026, 1, 2),
      end: Time.utc(2026, 1, 3),
      file_public: false,
      timezone: ActiveSupport::TimeZone['UTC']
    )
  end
  let(:deployments) { [deployment] }

  describe '.build' do
    it 'uses the configured client name and home URL as the package source' do
      allow(Settings.client).to receive(:host).and_return('ecoacoustics')

      expect(descriptor.fetch('sources')).to eq([
        { 'title' => 'Ecoacoustics', 'path' => Settings.client_routes.home_url.to_s }
      ])
    end

    it 'sorts taxonomic coverage by scientific name' do
      expect(descriptor.fetch('taxonomic')).to eq([
        { 'scientificName' => 'Amytornis striatus' },
        { 'scientificName' => 'Xema sabini' }
      ])
    end

    it 'emits licenses when the project has a valid license' do
      project.update!(license: 'CC-BY-4.0')

      expect(descriptor['licenses']).to eq([{ 'name' => 'CC-BY-4.0', 'scope' => 'data' },
                                            { 'name' => 'CC-BY-4.0', 'scope' => 'media' }])
    end

    it 'omits licenses when the project has no license' do
      project.update!(license: nil)

      expect(descriptor).not_to have_key('licenses')
    end

    context 'when license emission is disabled' do
      let(:options) { super().with(emit_project_license: false) }

      it 'does not emit licenses' do
        project.update!(license: 'CC-BY-4.0')

        expect(descriptor).not_to have_key('licenses')
      end
    end

    context 'with an unsupported custom project license' do
      before { project.update!(license: 'A custom license longer than thirty-two characters') }

      it 'raises a project license error' do
        expect { descriptor }.to raise_error(
          BawWorkers::Export::CamtrapDp::Errors::ProjectLicenseError,
          /Found unsupported custom license/
        )
      end
    end

    context 'with deployments in different timezones' do
      let(:deployments) do
        [
          deployment.with(start: Time.iso8601('2026-01-02T10:00:00+10:00'),
            end: Time.iso8601('2026-01-03T10:00:00+10:00')),
          deployment.with(start: Time.iso8601('2026-01-01T23:00:00-03:00'),
            end: Time.iso8601('2026-01-02T23:00:00-03:00'))
        ]
      end

      it 'uses the earliest start and latest end by instant, preserving their offsets' do
        expect(descriptor.fetch('temporal')).to eq(
          'start' => '2026-01-02T10:00:00+10:00',
          'end' => '2026-01-02T23:00:00-03:00'
        )
      end
    end
  end

  describe 'spatial coverage' do
    before { site.update!(latitude: 10, longitude: 20) }

    it 'represents a single deployment as a point' do
      expect(descriptor.fetch('spatial')).to eq('type' => 'Point', 'coordinates' => [20, 10])
    end

    context 'with multiple deployments' do
      let(:second_site) do
        create(:site, projects: [project], region:, creator: owner_user, latitude: 11, longitude: 21)
      end
      let(:deployments) { [deployment, deployment.with(site: second_site)] }

      it 'encloses the sites in a closed bounding polygon' do
        expect(descriptor.fetch('spatial')).to eq(
          'type' => 'Polygon',
          'coordinates' => [[[20, 10], [21, 10], [21, 11], [20, 11], [20, 10]]]
        )
      end

      it 'uses multipoint coverage when the latitude bounds have zero area' do
        second_site.update!(latitude: 10)

        expect(descriptor.fetch('spatial')).to eq(
          'type' => 'MultiPoint', 'coordinates' => [[20, 10], [21, 10]]
        )
      end

      it 'uses multipoint coverage when the longitude bounds have zero area' do
        second_site.update!(longitude: 20)

        expect(descriptor.fetch('spatial')).to eq(
          'type' => 'MultiPoint', 'coordinates' => [[20, 10], [20, 11]]
        )
      end

      it 'includes shared coordinates only once' do
        second_site.update!(latitude: 10, longitude: 20)

        expect(descriptor.fetch('spatial')).to eq(
          'type' => 'MultiPoint', 'coordinates' => [[20, 10]]
        )
      end
    end
  end
end
