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
  end
end
