# frozen_string_literal: true

require_relative 'errors/camtrap_dp_error'
module BawWorkers
  module Export
    module CamtrapDp
      # NOTE: ALA exports will be limited to a single project, enforced upstream, not in this module.
      # NOTE: :should_obfuscate option is respected by this module; the ability will be enforced in the controller
      #
      # The exporter orchestrates a Camtrap Data Package export from a given filter of taggings.
      # It generates a zip file containing the CSV tables and the datapackage.json file describing the package.
      class Exporter
        BATCH_SIZE = 1000

        # Options required to build a complete Camtrap Data Package export.
        #
        # @!attribute [r] user
        #   @return [User, nil] optional user requesting the export, to check permissions against
        #     (e.g. public_latitude, public_longitude).
        # @!attribute [r] should_obfuscate
        #   @return [Boolean, nil] optional, override the default obfuscation behaviour and indicate whether
        #     or not to obfuscate locations.
        # @!attribute [r] contributors
        #   @return [Array<Hash>] descriptor-compatible package contributors.
        # @!attribute [r] project_capture_method
        #   @return [Array<String>] project-level Camtrap DP captureMethod values (see BawWorkers::Dry::Types::CaptureMethod).
        # @!attribute [r] project_sampling_design
        #   @return [String] project-level Camtrap DP samplingDesign value (see BawWorkers::Dry::Types::SamplingDesign).
        # @!attribute [r] package_title
        #   @return [String] Optional title for this specific package, different from the project title
        # @!attribute [r] emit_project_license
        #   @return [Boolean] whether to include project license metadata in the package descriptor.
        # @!attribute [r] forced_timezone
        #   @return [ActiveSupport::TimeZone, TZInfo::Timezone, nil] optional timezone to apply to every
        #     exported recording, event, deployment, and temporal coverage timestamp. When omitted, each
        #     deployment uses its site's timezone; sites with no timezone or a zero UTC offset export in UTC.
        RequiredExporterOptions = Data.define(
          :user,
          :should_obfuscate,
          :contributors,
          :project_capture_method,
          :project_sampling_design,
          :package_title,
          :emit_project_license,
          :forced_timezone
        )

        # @param filter [ActiveRecord::Relation<Tagging>] a filter of taggings to export
        # @param exporter_options [RequiredExporterOptions] options required to build a complete Camtrap Data Package
        def initialize(filter, exporter_options)
          validate_filter(filter)
          validate_exporter_options(exporter_options)

          @filter = filter
          @options = exporter_options
        end

        # Generates the export and yields a manifest of metadata about the generated export to the provided block.
        #
        # @yield [PackageManifest] export metadata, including the path to the package zip file
        # @return the result of the block
        def call(&block)
          raise ArgumentError, 'block is required' unless block_given?

          # Bullet doesn't see the associations being used below and wrongly raises an UnoptimizedQueryError:
          # avoid eager loading.
          bullet_active = defined?(Bullet) && Bullet.enabled?
          Bullet.enable = false if bullet_active

          Rails.logger.info('Starting Camtrap DP export')
          rows_processed = 0

          scientific_names = Set.new
          audio_recordings = Set.new

          deployments = DeploymentAccumulator.new(forced_timezone: @options.forced_timezone)

          # Using find_each with default batch size to avoid pulling all records into memory at once.
          included.find_each(batch_size: BATCH_SIZE) do |tagging|
            deployment = deployments.add_or_update(tagging)
            first_media = audio_recordings.add?(tagging.audio_event.audio_recording_id)

            observation = Table::Observation.mapping(tagging, deployment)
            scientific_names << observation.scientificName if observation.scientificName.present?
            table_writers.observations << observation.ordered_values

            if first_media
              table_writers.media << Table::Media.mapping(tagging.audio_event.audio_recording,
                deployment).ordered_values
            end

            rows_processed += 1
            Rails.logger.info("Processed #{rows_processed} rows") if rows_processed % BATCH_SIZE == 0
          end

          raise ArgumentError, 'Filter returned no data, cannot export' if rows_processed.zero?

          write_deployments(table_writers.deployments, deployments.values)
          package = PackageMetadata.build(
            deployments: deployments.values,
            scientific_names: scientific_names,
            options: @options
          )

          close_table_writers

          validate_package(package)
          write_datapackage_file(package)

          manifest = zip_package

          Rails.logger.info('Finished Camtrap DP export')

          result = block.call(manifest)
          result
        ensure
          cleanup
          Bullet.enable = bullet_active if bullet_active
        end

        def public_package_path
          return nil unless @package_path&.exist?

          @package_path
        end

        TableWriters = Data.define(:observations, :deployments, :media)
        PackageManifest = Data.define(:package_path, :zip_path, :file_stats)

        private

        def validate_filter(filter)
          message = 'Expected filter to be '
          raise ArgumentError, "#{message}ActiveRecord::Relation" unless filter.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, "#{message}Tagging relation" unless filter.klass == Tagging
        end

        def validate_exporter_options(exporter_options)
          return if exporter_options.is_a?(RequiredExporterOptions)

          raise ArgumentError, 'exporter_options must be a RequiredExporterOptions object'
        end

        # Eager load audio_events because each audio_event usually has one tagging, so a join avoids
        # repeated queries, and audio_event columns are mostly small scalars, so the joined rows stay cheap.
        # Then preload recording and site to avoid duplicating their larger JSON blobs across tagging rows.
        def included
          @filter.eager_load(:audio_event).preload(:tag, audio_event: [:provenance, { audio_recording: :site }])
        end

        def write_deployments(writer, deployments)
          deployments.each do |deployment|
            writer << Table::Deployment.mapping(deployment, user: @options.user,
              should_obfuscate: @options.should_obfuscate).ordered_values
          end
        end

        def write_datapackage_file(package)
          package_files[:datapackage].write(JSON.pretty_generate(package.to_h))
        end

        def validate_package(package)
          Validator.validate_package(package, package_path:)
        end

        def table_writers
          @table_writers ||= TableWriters.new(
            observations: open_table_csv(package_files[:observations], headers: Table::Observation.attribute_names),
            deployments: open_table_csv(package_files[:deployments], headers: Table::Deployment.attribute_names),
            media: open_table_csv(package_files[:media], headers: Table::Media.attribute_names)
          )
        end

        # @return [CSV] an open CSV IO object in write-only mode
        def open_table_csv(path, headers:)
          CSV.open(path, 'w', write_headers: true, headers: headers, force_quotes: true)
        end

        def close_table_writers
          return if @table_writers.nil?

          @table_writers.deconstruct.each { |writer| writer.close unless writer.nil? || writer.closed? }
        end

        def exporter_temp_dir
          @exporter_temp_dir ||= Pathname.new(Dir.mktmpdir('exporter_', BawWorkers::Config.temp_dir))
        end

        def package_path
          @package_path ||= (exporter_temp_dir / PACKAGE_PATH).mkpath
        end

        def package_files
          @package_files ||= PACKAGE_FILENAMES.transform_values { |filename| package_path / filename }
        end

        def zip_path
          @zip_path ||= exporter_temp_dir / ZIP_PATH
        end

        # @return [PackageManifest]
        def zip_package
          Zip::File.open(zip_path, create: true) do |zip|
            package_files.each_value { |path| zip.add(path.basename.to_s, path) }
          end

          PackageManifest.new(
            package_path: package_path,
            zip_path: zip_path,
            file_stats: package_files.transform_values { |path| { size: path.size, mtime: path.mtime } }
          )
        end

        def cleanup
          close_table_writers
          FileUtils.rm_rf(@exporter_temp_dir) if @exporter_temp_dir&.exist?
        end
      end
    end
  end
end
