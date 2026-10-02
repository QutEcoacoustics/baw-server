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

    def csv_rows(filename) = CSV.read(package_path.join(filename), headers: true).map(&:to_h)

    def table_schema(name)
      directory = BawWorkers::Export::CamtrapDp::Profile::DIRECTORY
      filename = BawWorkers::Export::CamtrapDp::Profile::ASSET_FILES.fetch(name)
      JSON.parse(directory.join(filename).read)
    end

    def package_data
      {
        deployments: csv_rows('deployments.csv'),
        media: csv_rows('media.csv'),
        observations: csv_rows('observations.csv'),
        descriptor: JSON.parse(package_path.join('datapackage.json').read)
      }
    end

    def expect_spatial_point(longitude, latitude)
      expect(package_data[:descriptor].fetch('spatial')).to eq(
        'type' => 'Point', 'coordinates' => [longitude, latitude]
      )
    end

    def expect_exported_times_in(time_zone)
      ensure_timezone_with_seconds = ->(time) { time.in_time_zone(time_zone).iso8601(0) }
      ensure_timezone_with_microseconds = ->(time) { time.in_time_zone(time_zone).iso8601(6) }

      with_export_manifest do
        rows = package_data
        expect(rows[:deployments].first).to include(
          'deploymentStart' => ensure_timezone_with_seconds.call(audio_recording.recorded_date),
          'deploymentEnd' => ensure_timezone_with_seconds.call(audio_recording.recorded_end_date)
        )

        expect(rows[:media].first).to include(
          'timestamp' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date)
        )

        expect(rows[:observations].first).to include(
          'eventStart' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date + audio_event.start_time_seconds.seconds),
          'eventEnd' => ensure_timezone_with_microseconds.call(audio_recording.recorded_date + audio_event.end_time_seconds.seconds),
          'classificationTimestamp' => ensure_timezone_with_seconds.call(export_tagging.created_at)
        )

        expect(rows.dig(:descriptor, 'temporal')).to include(
          'start' => ensure_timezone_with_seconds.call(audio_recording.recorded_date),
          'end' => ensure_timezone_with_seconds.call(audio_recording.recorded_end_date)
        )
      end
    end

    it 'requires a block' do
      expect { subject.call }.to raise_error(ArgumentError, 'block is required')
    end

    it 'writes the complete descriptor from inputs, project metadata, and presets', :aggregate_failures do
      project.update!(name: 'Acoustic survey', description: 'Survey description', license: 'CC-BY-4.0')

      Timecop.freeze(Time.utc(2026, 1, 2, 3, 4, 5)) do
        descriptor = with_export_manifest { package_data[:descriptor] }

        expect(descriptor).to eq(
          'profile' => BawWorkers::Export::CamtrapDp::Profile::PROFILE_SOURCE_URL.to_s,
          'created' => '2026-01-02T03:04:05Z',
          'title' => 'Test Package Title',
          'contributors' => [{ 'title' => 'Alice', 'path' => 'http://www.test', 'role' => 'contributor' }],
          'project' => {
            'title' => 'Acoustic survey',
            'description' => 'Survey description',
            'path' => Api::UrlHelpers.project_url(id: project.id),
            'samplingDesign' => 'systematicRandom',
            'captureMethod' => ['continuous', 'recordingSchedule'],
            'individualAnimals' => false,
            'observationLevel' => ['media'],
            'protocolType' => 'acoustic'
          },
          'spatial' => { 'type' => 'Point', 'coordinates' => [site.public_longitude, site.public_latitude] },
          'temporal' => {
            'start' => audio_recording.recorded_date.utc.iso8601(0),
            'end' => audio_recording.recorded_end_date.utc.iso8601(0)
          },
          'taxonomic' => [{ 'scientificName' => export_tagging.tag.text }],
          'sources' => [{ 'title' => Settings.client.host.titlecase, 'path' => Settings.client_routes.home_url.to_s }],
          'licenses' => [
            { 'name' => 'CC-BY-4.0', 'scope' => 'data' },
            { 'name' => 'CC-BY-4.0', 'scope' => 'media' }
          ],
          'resources' => [:deployments, :media, :observations].map { |name|
            {
              'name' => name.to_s,
              'path' => "#{name}.csv",
              'profile' => 'tabular-data-resource',
              'format' => 'csv',
              'mediatype' => 'text/csv',
              'encoding' => 'utf-8',
              'schema' => table_schema(name)
            }
          }
        )
      end
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
          package_path.join(filename)
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

    it 'archives every package file with identical contents', :aggregate_failures do
      with_export_manifest do
        Zip::File.open(manifest.zip_path) do |zip|
          expect(zip.entries.map(&:name)).to match_array(package_filenames.values.map(&:to_s))
          package_filenames.each_value do |filename|
            expect(zip.read(filename.to_s)).to eq(package_path.join(filename).binread)
          end
        end
      end
    end

    it 'cleans up the temporary directory after yielding' do
      temp_dir = nil

      with_export_manifest do
        temp_dir = package_path.parent
        expect(Dir).to exist(temp_dir)
      end

      expect(Dir).not_to exist(temp_dir)
    end

    it 'cleans up and propagates errors raised by the caller' do
      temp_dir = nil

      expect {
        with_export_manifest do
          temp_dir = package_path.parent
          raise 'caller failed'
        end
      }.to raise_error(RuntimeError, 'caller failed')

      expect(Dir).not_to exist(temp_dir)
    end

    it 'writes configured client-host identifiers for table ids and foreign keys' do
      rows = with_export_manifest { package_data }
      authority = Settings.global_identifiers.authority

      expect(rows[:deployments].first).to include(
        'deploymentID' => "#{authority}/sites/#{site.id}",
        'locationID' => "#{authority}/sites/#{site.id}"
      )
      expect(rows[:media].first).to include(
        'mediaID' => "#{authority}/audio_recordings/#{audio_recording.id}",
        'deploymentID' => "#{authority}/sites/#{site.id}"
      )
      expect(rows[:observations].first).to include(
        'observationID' => "#{authority}/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}/taggings/#{export_tagging.id}",
        'deploymentID' => "#{authority}/sites/#{site.id}",
        'mediaID' => "#{authority}/audio_recordings/#{audio_recording.id}"
      )
    end

    context 'with no user or obfuscation override' do
      it 'writes public coordinates' do
        result = with_export_manifest {
          expect_spatial_point(site.public_longitude, site.public_latitude)
          package_data[:deployments].first
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
          expect_spatial_point(site.longitude, site.latitude)
          package_data[:deployments].first
        }

        expect(result).to include(
          'latitude' => site.latitude.to_s,
          'longitude' => site.longitude.to_s
        )
      end
    end

    context 'when a user without coordinate permission is supplied' do
      let(:export_options) { super().with(user: writer_user) }

      it 'keeps both table and descriptor coordinates obfuscated' do
        with_export_manifest do
          expect(package_data[:deployments].first).to include(
            'latitude' => site.obfuscated_latitude.to_s,
            'longitude' => site.obfuscated_longitude.to_s
          )
          expect_spatial_point(site.obfuscated_longitude, site.obfuscated_latitude)
        end
      end
    end

    context 'when obfuscation is enabled' do
      let(:export_options) { super().with(should_obfuscate: true) }

      it 'writes obfuscated coordinates' do
        result = with_export_manifest {
          expect_spatial_point(site.obfuscated_longitude, site.obfuscated_latitude)
          package_data[:deployments].first
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
          expect_spatial_point(site.longitude, site.latitude)
          package_data[:deployments].first
        }

        expect(result).to include(
          'latitude' => site.latitude.to_s,
          'longitude' => site.longitude.to_s
        )
      end
    end

    context 'when the site has custom obfuscated coordinates' do
      before { site.update!(custom_obfuscated_location: true) }

      it 'writes custom obfuscated coordinates with a blank numeric uncertainty' do
        result = with_export_manifest {
          expect_spatial_point(site.obfuscated_longitude, site.obfuscated_latitude)
          package_data[:deployments].first
        }

        expect(result).to include(
          'latitude' => site.obfuscated_latitude.to_s,
          'longitude' => site.obfuscated_longitude.to_s,
          'coordinateUncertainty' => ''
        )
      end
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

    context 'when a forced timezone is supplied' do
      let(:export_options) { super().with(forced_timezone: ActiveSupport::TimeZone['America/Sao_Paulo']) }

      before { site.update!(tzinfo_tz: 'Australia/Brisbane') }

      it 'writes exported time fields with the offset' do
        expect_exported_times_in(ActiveSupport::TimeZone['America/Sao_Paulo'])
      end
    end
  end
end
