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
      project_sampling_design: 'systematicRandom',
      emit_project_license: true,
      force_utc_offset: nil
    ).to_h
  end

  let(:filter) {
    Tagging.joins(:tag).where(tags: { type_of_tag: 'species_name', is_taxonomic: true })
  }

  let!(:export_tagging) do
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

  context 'with missing required exporter options' do
    let(:export_options) { super().except(:contributors) }

    it { expect { subject }.to raise_error(ArgumentError, /Missing required exporter option: contributors/) }
  end

  context 'with zero rows returned by the filter' do
    let(:filter) { Tagging.none }

    it { expect { subject }.to raise_error(ArgumentError, 'Filter returned no data, cannot export') }
  end

  describe '#call' do
    let(:package_filenames) { BawWorkers::Export::CamtrapDp::PACKAGE_FILENAMES }
    let(:manifest) { @manifest }
    let(:package_path) { manifest.package_path }

    def with_export_manifest
      subject.call do |manifest|
        @manifest = manifest
        yield manifest
      end
    end

    def csv_row(filename)
      CSV.read(package_path.join(filename), headers: true).first.to_h
    end

    def exported_times
      {
        deployments: csv_row('deployments.csv'),
        media: csv_row('media.csv'),
        observations: csv_row('observations.csv'),
        descriptor: JSON.parse(package_path.join('datapackage.json').read)
      }
    end

    def expect_exported_times_in(utc_offset_seconds)
      utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset_seconds)
      export_time = ->(time) { utc_offset_seconds.zero? ? time.utc : time.getlocal(utc_offset) }

      with_export_manifest do
        rows = exported_times
        expect(rows[:deployments]).to include(
          'deploymentStart' => export_time.call(audio_recording.recorded_date).iso8601(0),
          'deploymentEnd' => export_time.call(audio_recording.recorded_end_date).iso8601(0)
        )

        expect(rows[:media]).to include(
          'timestamp' => export_time.call(audio_recording.recorded_date).iso8601(6)
        )

        expect(rows[:observations]).to include(
          'eventStart' => export_time.call(audio_recording.recorded_date + audio_event.start_time_seconds.seconds).iso8601(6),
          'eventEnd' => export_time.call(audio_recording.recorded_date + audio_event.end_time_seconds.seconds).iso8601(6),
          'classificationTimestamp' => export_time.call(export_tagging.created_at).iso8601(0)
        )

        expect(rows[:descriptor]['temporal']).to include(
          'start' => export_time.call(audio_recording.recorded_date).iso8601,
          'end' => export_time.call(audio_recording.recorded_end_date).iso8601
        )
      end
    end

    it 'requires a block' do
      expect { subject.call }.to raise_error(ArgumentError, 'block is required')
    end

    context 'with invalid options that populate schema fields' do
      let(:export_options) { super().merge(project_capture_method: 1) }

      it {
        expect { subject.call { nil } }.to raise_error(
          Dry::Struct::Error,
          /1 \(Integer\) has invalid type for :captureMethod violates constraints/
        )
      }
    end

    it 'yields a manifest with the package file paths and stats' do
      with_export_manifest do
        temp_dir = package_path.parent

        expected_files = package_filenames.transform_values { |filename|
          subject.public_package_path.join(filename)
        }

        expected_file_stats = expected_files.transform_values { |file|
          { size: file.size, mtime: file.mtime }
        }

        expected_manifest = {
          package_path: temp_dir.join(BawWorkers::Export::CamtrapDp::PACKAGE_PATH),
          zip_path: temp_dir.join(BawWorkers::Export::CamtrapDp::ZIP_PATH),
          file_stats: expected_file_stats
        }

        expect(expected_files.values).to all(exist)
        expect(manifest.to_h).to eq(expected_manifest)
      end
    end

    it 'when yielding, includes all package files in the zip' do
      zip_entries = with_export_manifest {
        Zip::File.open(manifest.zip_path) { |zip| zip.entries.map(&:name) }
      }

      expect(zip_entries).to match_array(package_filenames.values)
    end

    it 'cleans up the temporary directory after yielding' do
      temp_dir = nil

      with_export_manifest do
        temp_dir = package_path.parent
        expect(Dir).to exist(temp_dir)
      end

      expect(Dir).not_to exist(temp_dir)
    end

    it 'calculates deployment start and end times from audio recordings' do
      recording = create(:audio_recording, recorded_date: Time.current, site:, creator: writer_user) { |ar|
        create(:audio_event, audio_recording: ar, creator: writer_user) { |ae|
          create(:tagging, audio_event: ae, tag: create(:tag_taxonomic_true_species), creator: writer_user)
        }
      }

      with_export_manifest do
        rows = exported_times
        expect(rows[:deployments]).to include(
          'deploymentStart' => audio_recording.recorded_date.utc.iso8601(0),
          'deploymentEnd' => recording.recorded_end_date.utc.iso8601(0)
        )
      end
    end

    context 'when obfuscation is enabled' do
      it 'writes obfuscated coordinates' do
        result = with_export_manifest {
          CSV.read(package_path.join('deployments.csv'), headers: true).first.to_h
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
        result = with_export_manifest {
          CSV.read(package_path.join('deployments.csv'), headers: true).first.to_h
        }

        expect(result).to include(
          'latitude' => site.latitude.to_s,
          'longitude' => site.longitude.to_s
        )
      end
    end

    context 'when the site has a timezone' do
      before do
        site.update!(tzinfo_tz: 'Australia/Brisbane')
      end

      it 'writes exported time fields in the site timezone' do
        expect_exported_times_in(36_000)
      end
    end

    context 'when the site timezone is UTC' do
      before do
        site.update!(tzinfo_tz: 'UTC')
      end

      it 'leaves exported time fields in UTC' do
        expect_exported_times_in(0)
      end
    end

    context 'when a force UTC offset is supplied' do
      let(:export_options) { super().merge(force_utc_offset: -14_400) }

      before do
        site.update!(tzinfo_tz: 'Australia/Brisbane')
      end

      it 'writes exported time fields with the offset' do
        expect_exported_times_in(-14_400)
      end
    end

    context 'when validating' do
      let(:validator) { BawWorkers::Export::CamtrapDp::Validator }
      let(:local_validation_profile_path) { BawWorkers::Export::CamtrapDp::Profile::LOCAL_VALIDATION_PROFILE_PATH }

      let(:package_descriptor) { JSON.parse(package_path.join('datapackage.json').read) }

      it 'replaces the profile path in the package descriptor with the local validation profile path' do
        with_export_manifest do
          package = validator.load_package(package_descriptor, package_path:)

          expect(package.profile.name).to eq(local_validation_profile_path)
        end
      end

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
              "The property '#/' of type object did not match all of the required schemas"
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
end
