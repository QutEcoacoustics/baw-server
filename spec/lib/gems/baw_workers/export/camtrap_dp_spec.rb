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
    let(:package_filenames) { BawWorkers::Export::CamtrapDp::PACKAGE_FILENAMES }

    it 'requires a block' do
      expect { subject.call }.to raise_error(ArgumentError, 'block is required')
    end

    it 'creates a temporary package directory and yields a manifest with paths and file stats' do
      subject.call do |manifest|
        temp_dir = manifest[:package_path].parent
        expected_files = package_filenames.transform_values { |filename|
          subject.public_package_path.join(filename)
        }
        file_stats = expected_files.transform_values { |file|
          { size: file.size, mtime: file.mtime }
        }

        expected_manifest = {
          package_path: temp_dir.join(BawWorkers::Export::CamtrapDp::PACKAGE_PATH),
          zip_path: temp_dir.join(BawWorkers::Export::CamtrapDp::ZIP_PATH),
          file_stats: file_stats
        }

        expect(manifest).to eq(expected_manifest)
      end
    end

    it 'includes all exported files in the zip' do
      zip_entries = subject.call { |manifest|
        Zip::File.open(manifest[:zip_path]) { |zip| zip.entries.map(&:name) }
      }

      expect(zip_entries).to match_array(package_filenames.values)
    end

    it 'cleans up the temporary directory after yielding' do
      temp_dir = nil

      subject.call do |manifest|
        temp_dir = manifest[:package_path].parent
        expect(Dir).to exist(temp_dir)
      end

      expect(Dir).not_to exist(temp_dir)
    end

    it 'creates a valid data package' do
      subject.call { |manifest|
        expect(manifest[:package_path].join(BawWorkers::Export::CamtrapDp::DATAPACKAGE_FILENAME)).to exist
      }
    end

    context 'when obfuscation is enabled' do
      it 'writes obfuscated coordinates' do
        result = subject.call { |manifest|
          CSV.read(manifest[:package_path].join('deployments.csv'), headers: true).first.to_h
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
          CSV.read(manifest[:package_path].join('deployments.csv'), headers: true).first.to_h
        }

        expect(result).to include(
          'latitude' => site.latitude.to_s,
          'longitude' => site.longitude.to_s
        )
      end
    end
  end
end
