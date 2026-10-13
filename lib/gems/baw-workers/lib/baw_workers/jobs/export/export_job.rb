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
          export.generate

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
            export.file.attach(
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
