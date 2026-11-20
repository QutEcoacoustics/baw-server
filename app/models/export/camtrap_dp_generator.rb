# frozen_string_literal: true

class Export
  # Generates a Camtrap DP package for the given export.
  #
  # Exports are scoped to the associated project and the creator's permissions on that project.
  #
  # Generator interface (implement for each export type):
  #   .new(export)
  #   #call { |io, filename, content_type| }
  #   #filter_as_relation
  #   Raise Export::UserFacingError for errors that are safe to show users.
  class CamtrapDpGenerator
    def initialize(export)
      @export = export
    end

    # @yield [io, filename, content_type] gives the caller the IO stream, the
    #   filename, and the content type of the generated export.
    def call
      camtrap_dp_exporter.call do |manifest|
        File.open(manifest.zip_path, 'rb') do |io|
          yield io, File.basename(manifest.zip_path), 'application/zip'
        end
      end
    rescue BawWorkers::Export::CamtrapDp::Errors::CamtrapDpError => e
      raise Export::UserFacingError, e.message
    end

    # @return [BawWorkers::Export::CamtrapDp::Exporter] the Camtrap DP exporter instance.
    def camtrap_dp_exporter
      BawWorkers::Export::CamtrapDp::Exporter.new(filter_as_relation, exporter_options)
    end

    # Taggings, filtered and scoped to the creator's permissions on the project.
    def filter_as_relation
      base_scope = Access::ByPermission.audio_events_tags(@export.creator, project_ids: [@export.project.id])
      whole_filter = { filter: @export.filter }

      query = Filter::Query.new(whole_filter, base_scope, Tagging, Tagging.filter_settings)
      query.query_filter(query.query_base)
    end

    # @return [BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions]
    def exporter_options
      options = @export.options || {}

      BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
        user: @export.creator,
        should_obfuscate: @export.obfuscate_locations,
        package_title: @export.name,
        contributors: options['contributors']&.map(&:symbolize_keys),
        project_capture_method: options['project_capture_method'],
        project_sampling_design: options['project_sampling_design'],
        emit_project_license: options['emit_project_license'],
        forced_timezone: TimeZoneHelper.ruby_tz_class(options['forced_timezone'])
      )
    end
  end
end
