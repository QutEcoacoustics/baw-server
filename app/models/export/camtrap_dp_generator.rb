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
      BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
        user: @export.creator,
        should_obfuscate: @export.obfuscate_locations,
        package_title: @export.name,
        contributors: @export.camtrap_dp_contributors&.map(&:symbolize_keys),
        project_capture_method: @export.camtrap_dp_project_capture_method,
        project_sampling_design: @export.camtrap_dp_project_sampling_design,
        emit_project_license: @export.camtrap_dp_emit_project_license,
        forced_timezone: @export.camtrap_dp_forced_timezone
      )
    end
  end
end
