# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Validator do
  create_entire_hierarchy

  subject(:validator) { described_class }

  let(:export_options) do
    BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
      user: nil,
      should_obfuscate: true,
      contributors: [{ title: 'Alice', path: 'http://www.test' }],
      project_capture_method: ['continuous', 'recordingSchedule'],
      project_sampling_design: 'systematicRandom',
      package_title: 'Test Package',
      emit_project_license: true,
      forced_timezone: nil
    )
  end

  let(:filter) { Tagging.joins(:tag).where(tags: { type_of_tag: 'species_name', is_taxonomic: true }) }

  let!(:export_tagging) {
    create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user)
  }

  let(:exporter) { BawWorkers::Export::CamtrapDp::Exporter.new(filter, export_options) }

  let(:manifest) { @manifest }
  let(:package_path) { manifest.package_path }
  let(:package_descriptor) { JSON.parse(package_path.join('datapackage.json').read) }
  let(:local_validation_profile_path) { BawWorkers::Export::CamtrapDp::Profile::LOCAL_VALIDATION_PROFILE_PATH }

  def with_export_manifest
    exporter.call do |manifest|
      @manifest = manifest
      yield manifest
    end
  end

  describe '.load_package' do
    it 'replaces the profile path in the package descriptor with the local validation profile path string' do
      with_export_manifest do
        package = validator.load_package(package_descriptor, package_path:)

        expect(package.profile.name).to eq(local_validation_profile_path.to_s)
      end
    end
  end

  describe '.validate_package' do
    it 'raises on invalid package metadata' do
      with_export_manifest do
        package_descriptor.delete('contributors')

        expect {
          validator.validate_package(package_descriptor, package_path:)
        }.to raise_error(
          BawWorkers::Export::CamtrapDp::Errors::DescriptorValidationError
        ) { |error|
          expect(error.message).to include(
            'Package descriptor validation error',
            "The property '#/' of type object did not match all of the required schemas",
            "The property '#/' did not contain a required property of 'contributors'"
          )
        }
      end
    end

    it 'raises when CSV headers do not match the schema field order' do
      with_export_manifest do
        invalid_csv = "\"wrong\",\"headers\"\ndata,data\n"
        File.write(package_path.join('deployments.csv'), invalid_csv)

        expect {
          validator.validate_package(package_descriptor, package_path:)
        }.to raise_error(
          BawWorkers::Export::CamtrapDp::Errors::CsvValidationError
        ) { |error|
          expect(error.message).to include(
            "CSV header validation error in resource 'deployments'",
            'expected ["deploymentID", "locationID"',
            'got ["wrong", "headers"]'
          )
        }
      end
    end

    it 'raises on invalid CSV data' do
      with_export_manifest do
        deployments_path = package_path.join('deployments.csv')

        deployments = CSV.read(deployments_path, headers: true)
        deployments[0]['latitude'] = 'invalid'
        deployments_path.write(deployments.to_csv)

        expect {
          validator.validate_package(package_descriptor, package_path:)
        }.to raise_error(
          BawWorkers::Export::CamtrapDp::Errors::CsvValidationError,
          /CSV data validation error in resource 'deployments': invalid is not a number/
        )
      end
    end
  end
end
