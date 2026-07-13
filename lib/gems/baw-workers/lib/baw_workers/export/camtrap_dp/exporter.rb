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
        # Options required to build a complete Camtrap Data Package export.
        #
        # @!attribute [r] force_utc_offset
        #   @return [Integer, nil] optional UTC offset in seconds to apply to every exported recording, event,
        #     deployment, and temporal coverage timestamp. When omitted, each deployment uses its site's timezone;
        #     sites with no timezone or a zero UTC offset export in UTC.
        RequiredExporterOptions = Data.define(
          :should_obfuscate,
          :contributors,
          :project_capture_method,
          :project_sampling_design,
          :emit_project_license,
          :force_utc_offset
        )

        def initialize(filter, **exporter_options)
          @filter = validate_filter(filter)
          @options = required_exporter_options(exporter_options)
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

          scientific_names = Set.new
          audio_recordings = Set.new

          deployments = DeploymentAccumulator.new(force_utc_offset: @options.force_utc_offset)

          # Using find_each with default batch size to avoid pulling all records into memory at once.
          included.find_each do |tagging|
            deployment = deployments.add_or_update(tagging)
            first_media = audio_recordings.add?(tagging.audio_event.audio_recording_id)

            observation = Table::Observation.mapping(tagging, deployment)
            scientific_names << observation.scientificName if observation.scientificName.present?
            table_writers.observations << observation.ordered_values

            if first_media
              table_writers.media << Table::Media.mapping(tagging.audio_event.audio_recording,
                deployment).ordered_values
            end
          end

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
          raise ArgumentError, 'Filter returned no data, cannot export' if filter.empty?

          filter
        end

        def required_exporter_options(exporter_options)
          missing = RequiredExporterOptions.members - exporter_options.keys
          raise ArgumentError, "Missing required exporter option: #{missing.first}" if missing.any?

          RequiredExporterOptions.new(**exporter_options)
        end

        def included
          @included ||= @filter.includes(:tag, audio_event: [:provenance, :audio_recording])
        end

        def write_deployments(writer, deployments)
          deployments.each do |deployment|
            writer << Table::Deployment.mapping(deployment,
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
          return if table_writers.nil?

          table_writers.deconstruct.each { |writer| writer.close unless writer.nil? || writer.closed? }
        end

        def exporter_temp_dir
          @exporter_temp_dir ||= Pathname.new(Dir.mktmpdir('exporter_', BawWorkers::Config.temp_dir))
        end

        def package_path
          @package_path ||= exporter_temp_dir.join(PACKAGE_PATH).tap { |path| FileUtils.mkdir_p(path) }
        end

        def package_files
          @package_files ||= PACKAGE_FILENAMES.transform_values { |filename| package_path.join(filename) }
        end

        def zip_path
          @zip_path ||= exporter_temp_dir.join(ZIP_PATH)
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
          FileUtils.rm_rf(exporter_temp_dir)
        end
      end
    end
  end
end
