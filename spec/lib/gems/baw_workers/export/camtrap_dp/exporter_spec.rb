# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Exporter do
  create_entire_hierarchy

  subject(:exporter) { BawWorkers::Export::CamtrapDp::Exporter.new(filter, export_options) }

  let(:export_options) do
    BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
      user: nil,
      should_obfuscate: nil,
      contributors: [{ title: 'Alice', path: 'http://www.test' }],
      project_capture_method: ['continuous', 'recordingSchedule'],
      project_sampling_design: 'systematicRandom',
      package_title: 'Test Package Title',
      emit_project_license: true,
      forced_timezone: nil
    )
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

  context 'with invalid exporter options' do
    let(:export_options) { 'not a RequiredExporterOptions' }

    error_message = 'exporter_options must be a RequiredExporterOptions object'
    it { expect { subject }.to raise_error(ArgumentError, error_message) }
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

    def csv_row(filename) = CSV.read(package_path.join(filename), headers: true).first.to_h

    def package_data
      {
        deployments: csv_row('deployments.csv'),
        media: csv_row('media.csv'),
        observations: csv_row('observations.csv'),
        descriptor: JSON.parse(package_path.join('datapackage.json').read)
      }
    end

    def expect_exported_times_in(time_zone)
      ensure_timezone_with_precision = ->(precision, time) { time.in_time_zone(time_zone).iso8601(precision) }.curry
      ensure_timezone_with_seconds = ensure_timezone_with_precision.call(0)
      ensure_timezone_with_microseconds = ensure_timezone_with_precision.call(6)

      with_export_manifest do
        rows = package_data
        expect(rows[:deployments]).to include(
          'deploymentStart' => ensure_timezone_with_seconds.call(audio_recording.recorded_date),
          'deploymentEnd' => ensure_timezone_with_seconds.call(audio_recording.recorded_end_date)
        )

        expect(rows[:media]).to include(
          'timestamp' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date)
        )

        expect(rows[:observations]).to include(
          'eventStart' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date + audio_event.start_time_seconds.seconds),
          'eventEnd' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date + audio_event.end_time_seconds.seconds),
          'classificationTimestamp' => ensure_timezone_with_seconds.call(export_tagging.created_at)
        )

        expect(rows[:descriptor]['temporal']).to include(
          'start' => ensure_timezone_with_seconds.call(audio_recording.recorded_date),
          'end' => ensure_timezone_with_seconds.call(audio_recording.recorded_end_date)
        )
      end
    end

    it 'requires a block' do
      expect { subject.call }.to raise_error(ArgumentError, 'block is required')
    end

    context 'with invalid options that populate schema fields' do
      let(:export_options) { super().with(project_capture_method: 1) }

      it {
        expect { subject.call { nil } }.to raise_error(
          Dry::Struct::Error,
          /1 \(Integer\) has invalid type for :captureMethod violates constraints/
        )
      }
    end

    context 'with invalid forced_timezone type' do
      let(:export_options) { super().with(forced_timezone: 'invalid') }
      let(:error_message) { /forced_timezone: got String, expected ActiveSupport::TimeZone or TZInfo::Timezone/ }

      it { expect { subject.call { nil } }.to raise_error(ArgumentError, error_message) }
    end

    context 'with zero rows returned by the filter' do
      let(:filter) { Tagging.none }

      it 'raises an error' do
        expect { subject.call { nil } }.to raise_error(ArgumentError, 'Filter returned no data, cannot export')
      end
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

      expect(zip_entries).to match_array(package_filenames.values.map(&:to_s))
    end

    it 'cleans up the temporary directory after yielding' do
      temp_dir = nil

      with_export_manifest do
        temp_dir = package_path.parent
        expect(Dir).to exist(temp_dir)
      end

      expect(Dir).not_to exist(temp_dir)
    end

    it 'calculates deployment start and end times from all site audio recordings' do
      earliest_recording = create(:audio_recording, recorded_date: audio_recording.recorded_date - 1.day, site:,
        creator: writer_user)
      latest_recording = create(:audio_recording, recorded_date: audio_recording.recorded_date + 1.day, site:,
        creator: writer_user)

      with_export_manifest do
        rows = package_data
        expect(rows[:deployments]).to include(
          'deploymentStart' => earliest_recording.recorded_date.utc.iso8601(0),
          'deploymentEnd' => latest_recording.recorded_end_date.utc.iso8601(0)
        )
        expect(rows[:descriptor]['temporal']).to include(
          'start' => earliest_recording.recorded_date.utc.iso8601(0),
          'end' => latest_recording.recorded_end_date.utc.iso8601(0)
        )
      end
    end

    it 'writes configured client-host identifiers for table ids and foreign keys' do
      rows = with_export_manifest { package_data }

      site_identifier = BawWorkers::Export::CamtrapDp::Identifier.site(site)
      audio_recording_identifier = BawWorkers::Export::CamtrapDp::Identifier.audio_recording(audio_recording)
      tagging_identifier = BawWorkers::Export::CamtrapDp::Identifier.tagging(export_tagging)

      expect([site_identifier, audio_recording_identifier, tagging_identifier]).to all(exclude('://'))

      expect(rows[:deployments]).to include(
        'deploymentID' => site_identifier,
        'locationID' => site_identifier
      )
      expect(rows[:media]).to include(
        'mediaID' => audio_recording_identifier,
        'deploymentID' => site_identifier
      )
      expect(rows[:observations]).to include(
        'observationID' => tagging_identifier,
        'deploymentID' => site_identifier,
        'mediaID' => audio_recording_identifier
      )
    end

    it 'writes machine classification details from audio event provenance' do
      audio_event.update!(provenance:)

      result = with_export_manifest {
        CSV.read(package_path.join('observations.csv'), headers: true).first.to_h
      }

      expect(result).to include(
        'classificationMethod' => 'machine',
        'classifiedBy' => provenance.name
      )
    end

    it 'writes a default package source using the client settings' do
      allow(Settings.client).to receive(:host).and_return('ecoacoustics')

      result = with_export_manifest {
        JSON.parse(package_path.join('datapackage.json').read).fetch('sources')
      }

      expect(result).to contain_exactly(
        include(
          'title' => 'Ecoacoustics',
          'path' => Settings.client_routes.home_url
        )
      )
    end

    context 'with no user or obfuscation override' do
      it 'writes public coordinates' do
        result = with_export_manifest {
          CSV.read(package_path.join('deployments.csv'), headers: true).first.to_h
        }

        expect(result).to include(
          'latitude' => site.public_latitude.to_s,
          'longitude' => site.public_longitude.to_s
        )
      end
    end

    context 'when a user with permission is supplied' do
      let(:export_options) { super().with(user: owner_user) }

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

    context 'when obfuscation is enabled' do
      let(:export_options) { super().with(should_obfuscate: true) }

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
      let(:export_options) { super().with(should_obfuscate: false) }

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

    it 'writes taxonomic coverage from observed scientific names' do
      result = with_export_manifest {
        JSON.parse(package_path.join('datapackage.json').read).fetch('taxonomic')
      }

      expect(result).to contain_exactly(
        include('scientificName' => export_tagging.tag.text)
      )
    end

    context 'when the site has no timezone' do
      before { site.update!(tzinfo_tz: nil) }

      it 'falls back to UTC for exported time fields' do
        expect_exported_times_in(ActiveSupport::TimeZone['UTC'])
      end
    end

    context 'when the site has a timezone' do
      before { site.update!(tzinfo_tz: 'Australia/Brisbane') }

      it 'writes exported time fields in the site timezone' do
        expect_exported_times_in(ActiveSupport::TimeZone['Australia/Brisbane'])
      end
    end

    context 'when the site timezone is UTC' do
      before { site.update!(tzinfo_tz: 'UTC') }

      it 'leaves exported time fields in UTC' do
        expect_exported_times_in(ActiveSupport::TimeZone['UTC'])
      end
    end

    context 'when a force UTC offset is supplied' do
      let(:export_options) { super().with(forced_timezone: ActiveSupport::TimeZone['America/Sao_Paulo']) }

      before { site.update!(tzinfo_tz: 'Australia/Brisbane') }

      it 'writes exported time fields with the offset' do
        expect_exported_times_in(ActiveSupport::TimeZone['America/Sao_Paulo'])
      end
    end
  end
end
