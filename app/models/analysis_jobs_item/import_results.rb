# frozen_string_literal: true

class AnalysisJobsItem
  # Helper methods for importing results
  module ImportResults
    # scans the results directory for files that could contain audio event
    # results and imports them

    # Scans the results directory for files that could contain audio events
    # and imports them.
    # @return [Dry::Monads::Result]
    def import_results!
      return unless result_success?

      # gather metadata sources from database
      # - audio recording
      # - script
      # - provenance
      audio_recording = AudioRecording.with_discarded.find(audio_recording_id)
      script = Script.find(script_id)
      provenance = Provenance.with_discarded.find(script.provenance_id)

      # scan for files with valid extension
      files = scan_results_directory(script.event_import_glob)

      if files.empty?
        # it's not a failure, but we didn't find any files to import
        return Dry::Monads.Success()
      end

      # create or load audio event import
      import = create_or_find_audio_event_import

      # check we haven't already imported this file
      if already_imported? import
        # TODO? do we delete the existing import and re-import?
        raise NotImplementedError, 'Results have already been imported, don\'t know how to handle this'
      end

      # finally import the results
      failures = []
      ActiveRecord::Base.transaction do
        files.each do |file|
          Rails.logger.info "Importing results from #{file}"

          result = import_results(file, import, audio_recording, provenance)

          # either all work or they don't
          next unless result.failure?

          relative_path = file.relative_path_from(results_absolute_path)
          message = "Failure importing `#{relative_path}`, #{result.failure.downcase_first}"
          failures << message
        end

        raise ActiveRecord::Rollback if failures.any?
      end

      failures.empty? ? Dry::Monads.Success() : Dry::Monads.Failure(failures)
    end

    private

    def scan_results_directory(glob)
      return [] if glob.blank?

      glob = "**/*#{glob}" unless glob.start_with?('**/')

      results_absolute_path.glob(glob).filter(&:file?)
    end

    def already_imported?(import)
      # we can import more than one file per analysis job item
      # but we really want to know if any have been imported
      AudioEventImportFile.exists?(
        analysis_jobs_item_id: id,
        audio_event_import_id: import.id
      )
    end

    def create_or_find_audio_event_import
      return @create_or_find_audio_event_import if defined?(@create_or_find_audio_event_import)

      AudioEventImport.transaction do
        @create_or_find_audio_event_import = AudioEventImport.with_discarded.find_by(analysis_job_id:)

        if @create_or_find_audio_event_import.nil?
          @create_or_find_audio_event_import = AudioEventImport.create!(
            analysis_job_id:,
            name: "Import for #{analysis_job.name}",
            description: "Automatic results import for #{analysis_job.name}",
            creator_id: analysis_job.creator_id
          )
        end
      end

      @create_or_find_audio_event_import
    end

    def import_results(file, import, audio_recording, provenance)
      # create the import file
      import_file = AudioEventImportFile.create!(
        audio_event_import_id: import.id,
        analysis_jobs_item_id: id,
        path: file.relative_path_from(results_absolute_path).to_s
      )

      # import the events
      parser = Api::AudioEventParser.new(
        import_file,
        analysis_job.creator,
        provenance:,
        # force events to be associated with the audio recording
        audio_recording:
      )

      result = parser.parse_and_commit(file.read, file.basename.to_s)

      if result.failure?
        summary = parser.summarize_errors.format_inline_list(quote: "'")
        new_message = "#{result.failure}: #{summary}"
        result = Dry::Monads.Failure(new_message)
      end

      result
    end
  end
end
