# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Export
      # FUTURE scope: if user doesn't supply a name, provide a default name (e.g. see controller helper and harvest thing).
      class ExportJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.export.queue

        # Change arguments.rb to use arg.is_a?
        # perform_expects ::ActiveRecord::Base

        perform_expects ::Export

        def perform(export)
          # TODO: Claim this row as working here; set started_at and clear error/finished_at.
          # TODO: Reject duplicate or terminal attempts before starting the export.
          user = export.creator

          # TODO: Table becomes more generic, add options column for hash of options (json).
          # TODO: Add a type column for export type: e.g. 'camtrap' and in the future 'csv_*'
          # Then just get export.options.merge(user: user)
          # Validation on the export that the creator is the owner if true. Applied to every export.
          # And this can stay as a stand-alone column.
          #
          # TODO: Replace test options with persisted request options; use name for package_title.
          options = BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
            user: user,
            # TODO: Pass export.obfuscate_locations here; authorize false when accepting the request.
            should_obfuscate: nil,
            contributors: [{ title: 'Alice', path: 'http://www.test' }],
            project_capture_method: ['continuous', 'recordingSchedule'],
            project_sampling_design: 'systematicRandom',
            package_title: export.name,
            emit_project_license: true,
            forced_timezone: nil
          )

          # TODO: See analysis_job model. Replicate on the model. Reusable across models
          # Exports has project FK. Use the predicate in filter as relation, same as analysis_job. Exports will all be scoped to a single project.
          # TODO: Might have to support passing in a base model to filter_as_relation. Doesn't have to be completely generic now.
          # Filter as relation could case on the type column.
          # Just add a type column, validate type is always camtrap_dp for now. Varchar 16
          export.filter_as_relation

          # TODO: Restrict this scope to project_id when present; define single-project Camtrap enforcement.
          scope = Access::ByPermission.audio_events_tags(user)

          # Get the filter stored on the data package export record.
          # TODO: Wrap stored conditions in { filter: ... }; use an export-owned projection.
          filter = export.filter.with_indifferent_access
          relation = Filter::Query.new(
            filter,
            scope,
            Tagging,
            Tagging.filter_settings # NOTE: Added creator_id to render_fields; needed by export
          ).query_without_paging_sorting

          exporter = BawWorkers::Export::CamtrapDp::Exporter.new(
            relation,
            options
          )

          # TODO: export should have a method that generates the package and attaches it to the data package export export. Or sub-folder for the model.
          exporter.call do |manifest|
            # attach the zip to the data package export
            # TODO: Use File.open(manifest.zip_path, 'rb') with a block around attach to close the IO.
            export.archive.attach(
              io: File.open(manifest.zip_path),
              filename: File.basename(manifest.zip_path),
              content_type: 'application/zip'
            )
          end

          # TODO: You run generate on the model, the status changes. Everything should be on generate method on the model.

          # TODO: Set finished_at and clear error in this same ready update; set expires_at once retention is defined.
          export.update!(status: ::Export::STATUS_READY)
          # Rescue inside generate, and then re-raise.
          # TODO: Storing errors... can't show to users. Stack trace can be sensitive. see analysis job model end.
          # And see 359 on script model.
          # So we should be verifying / validate as much as we can before attempting the export.
          # But if schema validation fails ... this is where we catch the camtrap errors and store those ones in error and we can show them to the user.
          # If catch the camtrap errors, don't need to re-raise them. (maybe email?)
          # But don't catch standard error because can have PG or ssh or timeout errors.
          # Application job catches on standard error and notifies and discards.
          # Don't think I need any extra retry_on or discard_ons. E.g. see remote cancel job which does.
          # As long as there are no transient errors (in which case you can use retry_on). But camtrap ones are permanent.
        rescue StandardError => e
          # TODO: Guard failed lookups; save failed status, error: e.message, and finished_at in one update here.
          export.update!(status: ::Export::STATUS_FAILED)
          export.update!(error: e.message)
          # TODO: Re-raise the original error here; preserve it if saving the failure itself raises.
        end

        def create_job_id
          # TODO: Generate an identity keyed by the export ID so repeated enqueues can be deduplicated.
          # Can't get 2 jobs that run if you use uid. Automatically deduplicates.
          # Use generate_keyed_id
          #
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          job_id
        end
      end
    end
  end
end
