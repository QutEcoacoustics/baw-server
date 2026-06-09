# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Exporter do
  create_entire_hierarchy

  subject(:exporter) do
    BawWorkers::Export::CamtrapDp::Exporter.new(
      filter, **export_options
    )
  end

  let(:export_options) do
    BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
      should_obfuscate: true,
      contributors: [{ title: 'Alice' }],
      project_capture_method: ['continuous', 'recordingSchedule'],
      project_individual_animals: false,
      observation_level: ['media'],
      project_sampling_design: 'systematicRandom',
      project_title: 'My Project'
    ).to_h
  end

  let(:filter) {
    Tagging.joins(:tag).where(tags: { type_of_tag: 'species_name', is_taxonomic: true })
  }

  before do
    create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user)
  end

  context 'with invalid filter object' do
    let(:filter) { 'not a relation' }

    it { expect { subject }.to raise_error(ArgumentError, 'Expected filter to be ActiveRecord::Relation') }
  end

  context 'with a missing Tagging relation on filter' do
    let(:filter) { AudioEvent.all }

    it { expect { subject }.to raise_error(ArgumentError, /Expected filter to be Tagging relation/) }
  end

  describe '#call' do
    let(:expected_files) do
      {
        observations: 'observations.csv',
        deployments: 'deployments.csv',
        media: 'media.csv',
        datapackage: 'datapackage.json'
      }
    end

    it 'requires a block' do
      expect { subject.call }.to raise_error(ArgumentError, 'block is required')
    end

    it 'creates a temporary datapackage directory and yields a manifest with paths and file stats' do
      subject.call do |manifest|
        expected_manifest = {
          datapackage_path: manifest[:datapackage_path].parent.join('dp'),
          zip_path: manifest[:datapackage_path].parent.join('dp.zip'),
          file_stats: expected_files.transform_values { |filename|
            file_path = manifest[:datapackage_path].join(filename)
            { size: file_path.size, mtime: file_path.mtime }
          }
        }

        expect(manifest).to eq(expected_manifest)
      end
    end

    it 'includes all exported files in the zip' do
      zip_entries = subject.call { |manifest|
        Zip::File.open(manifest[:zip_path]) { |zip| zip.entries.map(&:name) }
      }

      expect(zip_entries).to match_array(expected_files.values)
    end

    it 'cleans up the temporary directory after yielding' do
      temp_dir = nil

      subject.call do |manifest|
        temp_dir = manifest[:datapackage_path].parent
        expect(Dir).to exist(temp_dir)
      end

      expect(Dir).not_to exist(temp_dir)
    end

    it 'creates a valid data package' do
      subject.call { |manifest|
        package_json = load_package_json(manifest)
        package = DataPackage::Package.new(package_json, opts: { base: manifest[:datapackage_path].to_s })

        result = validate_package(package)

        expect(result).to be_valid, result.to_s
        package.resources.each { |resource| expect_fieldnames_match_headers(resource) }
      }
    end

    context 'when obfuscation is enabled' do
      it 'writes obfuscated coordinates' do
        result = subject.call { |manifest|
          CSV.read(manifest[:datapackage_path].join('deployments.csv'), headers: true).first.to_h
        }

        expect(result).to include(
          'latitude' => site.obfuscated_latitude.to_s,
          'longitude' => site.obfuscated_longitude.to_s
        )
      end
    end

    context 'when obfuscation is disabled' do
      let(:export_options) { super().merge(should_obfuscate: false) }

      it 'writes real coordinates' do
        result = subject.call { |manifest|
          CSV.read(manifest[:datapackage_path].join('deployments.csv'), headers: true).first.to_h
        }

        expect(result).to include(
          'latitude' => site.latitude.to_s,
          'longitude' => site.longitude.to_s
        )
      end
    end
  end
end

# Container for package validation result with a custom to_s for easier debugging in tests.
ValidationResult = Struct.new(:valid?, :errors, keyword_init: true) do
  def to_s
    valid? ? 'Package is valid' : "Package validation failed:\n#{errors.map { "  - #{_1}" }.join("\n")}"
  end
end

# Helper to validate the descriptor and resource schemas and csv data, collecting errors,
# since DataPackage gem's validation methods only check the schemas.
def validate_package(package)
  errors = []

  descriptor_errors = package.iter_errors { _1 }
  errors.concat(descriptor_errors.map { "Descriptor: #{_1}" })

  if errors.empty?
    package.resources.each do |resource|
      resource.iter { |_| }
    rescue TableSchema::Exception => e
      errors << "Resource '#{resource.name}': #{e.message}"
    end
  end

  ValidationResult.new(valid?: errors.empty?, errors:)
end

# If the csv field order doesn't match the schema, validation can fail with cast errors, which takes longer to debug.
def expect_fieldnames_match_headers(resource)
  expect(resource.schema.field_names).to eq(resource.headers)
end

# Parse the package json and update the profile reference to the local validation profile, which has external refs inlined.
def load_package_json(manifest)
  package_json = JSON.parse(File.read(manifest[:datapackage_path].join('datapackage.json')), symbolize_names: false)
  package_json['profile'] = BawWorkers::Export::CamtrapDp::Datapackage.local_validation_profile_path
  package_json
end
