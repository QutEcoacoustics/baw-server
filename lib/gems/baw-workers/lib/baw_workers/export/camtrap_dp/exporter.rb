# frozen_string_literal: true

require 'zip'

# The exporter orchestrates a Camtrap Data Package export from a given filter of taggings.
# It generates a zip file containing the CSV tables and the datapackage.json file describing the package.
#
# NOTE: ALA exports will be limited to a single project, enforced upstream, not in this module.
# NOTE: :should_obfuscate option is respected and the ability to set this will be enforced in the controller
module BawWorkers
  module Export
    module CamtrapDp
      class Exporter
        # Required fields that we can't currently generate or pull from the database
        RequiredExporterOptions = Data.define(
          :should_obfuscate,
          :contributors,
          :project_capture_method,
          :project_individual_animals,
          :observation_level,
          :project_sampling_design,
          :project_title
        )

        def initialize(filter, **exporter_options)
          @filter = validate_filter(filter)
          @options = RequiredExporterOptions.new(**exporter_options)
        end

        # Generates the export and yields a manifest of metadata about the generated export to the provided block.
        #
        # @yield [Hash manifest] manifest contains metadata about the generated export, including the path to the zip file
        # @return the result of block
        def call(&block)
          raise ArgumentError, 'block is required' unless block_given?

          # Bullet doesn't see the associations being used below and wrongly raises an UnoptimizedQueryError:
          # avoid eager loading.
          bullet_active = defined?(Bullet) && Bullet.enabled?
          Bullet.enable = false if bullet_active

          scientific_names = Set.new
          audio_recordings = Set.new
          deployments = DeploymentAccumulator.new

          # Using find_each with default batch size to avoid pulling all records into memory at once.
          included.find_each do |tagging|
            table_writers.observations << Table::Observation.mapping(tagging).full_values

            deployment = deployments.add_or_update(tagging)
            first_media = audio_recordings.add(tagging.audio_event.audio_recording_id)

            if first_media
              table_writers.media << Table::Media.mapping(
                tagging.audio_event.audio_recording,
                deployment.file_public
              ).full_values
            end
          end

          write_deployments(table_writers.deployments, deployments.values)

          package = PackageMetadata.build(
            deployments: deployments.values,
            scientific_names: scientific_names,
            options: @options
          )

          write_datapackage_file(package)
          close_table_writers

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

        private

        def validate_filter(filter)
          message = 'Expected filter to be '
          raise ArgumentError, message + 'ActiveRecord::Relation' unless filter.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, message + 'Tagging relation' unless filter.klass == Tagging

          filter
        end

        def included
          @included ||= @filter
            .includes(:tag, audio_event: [:provenance, { audio_recording: { site: { projects: :permissions } } }])
        end

        def write_deployments(writer, deployments)
          deployments.each do |deployment|
            writer << Table::Deployment.mapping(deployment.site,
              deployment_start: deployment.start,
              deployment_end: deployment.end,
              should_obfuscate: @options.should_obfuscate).full_values
          end
        end

        def write_datapackage_file(package)
          File.write(package_files[:datapackage], JSON.pretty_generate(package.to_h))
        end

        TableWriters = Data.define(:observations, :deployments, :media)

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
          @temp_dir ||= Pathname.new(Dir.mktmpdir('exporter_', Pathname.new(BawWorkers::Config.temp_dir)))
        end

        def package_path
          @package_path ||= exporter_temp_dir.join(PACKAGE_PATH).tap { |path| FileUtils.mkdir_p(path) }
        end

        def package_files
          @files ||= PACKAGE_FILENAMES.transform_values { |filename| package_path.join(filename) }
        end

        def zip_path
          @zip_path ||= exporter_temp_dir.join(ZIP_PATH)
        end

        def zip_package
          Zip::File.open(zip_path, create: true) do |zip|
            package_files.each_value { |path| zip.add(path.basename.to_s, path) }
          end

          { package_path: package_path,
            zip_path: zip_path,
            file_stats: package_files.transform_values { |path| { size: path.size, mtime: path.mtime } } }
        end

        def cleanup
          close_table_writers
          FileUtils.rm_rf(exporter_temp_dir)
        end
      end
    end
  end
end
