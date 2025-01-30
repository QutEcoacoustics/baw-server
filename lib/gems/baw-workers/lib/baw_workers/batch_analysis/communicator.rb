# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    # Starts analyses on a compute cluster.
    # This class is the middle ground between our application and the remote cluster.
    # It translates our models into generic commands and in future may
    # adapt to various job backends (even though currently only PBS is supported).
    # This translation layer looks verbose if you just compare it to the PBS::Connection
    # class, but that layer of indirection is important for future flexibility.
    class Communicator
      include ::Dry::Monads[:result]

      # scratch is cleaned automatically by PBS
      SCRATCH_DIR = Pathname("$#{::PBS::Connection::ENV_TMPDIR}")

      # wherever the job file is submitted from, we use this as our
      # working directory and output directory
      WORKING_DIR = Pathname("$#{::PBS::Connection::ENV_PBS_O_WORKDIR}")

      # these resources are all cleaned after a job run by PBS
      CONFIG_DIR = SCRATCH_DIR / 'config'
      SOURCE_DIR = SCRATCH_DIR / 'source'
      TEMP_DIR = SCRATCH_DIR / 'tmp'

      # Number of seconds to wait before attempting to download the file again
      DOWNLOAD_RETRY = 180
      DOWNLOAD_ATTEMPTS = 6
      MINIMUM_WALLTIME = (DOWNLOAD_RETRY * DOWNLOAD_ATTEMPTS) + 120

      # resources to be **added** on to resources requested by the script
      BASE_RESOURCES = DynamicResourceList.new(
        # cater for failed download attempts and also two other minutes
        # to do the actual download, start containers, etc.
        walltime: MINIMUM_WALLTIME
      )

      # safeguard against any calculation shenanigans
      MINIMUM_RESOURCES = {
        walltime: MINIMUM_WALLTIME,
        ncpus: 1,
        memory: 2.gigabytes
      }.freeze

      include ::BawApp::Inspector

      inspector excludes: [:@settings]

      # @return [::PBS::Connection]
      attr_reader :connection

      # @return [BawApp::BatchAnalysisSettings]
      attr_reader :settings

      def initialize
        @settings = Settings.batch_analysis
        @connection = ::PBS::Connection.new(settings, Settings.organisation_names.site_short_name)
        @url_helpers = Api::UrlHelpers::Base.new
      end

      # Test if the connection to the remote cluster.
      # @return [Boolean] true if the connection was established
      def remote_connected?
        connection.test_connection
      end

      # Count the number of enqueued jobs. That is all jobs in the remote
      # queue regardless of their state.
      # @return [::Dry::Monads::Result<Integer>]
      def count_enqueued_jobs
        connection.fetch_enqueued_count
      end

      # Count the maximum allowed number of jobs that are allowed to be queued.
      # `nil` is returned if the limit is unknown, or not set.
      # @return [::Dry::Monads::Result<Integer,nil>]
      def maximum_queued_jobs
        connection.fetch_max_queued
      end

      # Removes a job from the cluster queue.
      # Will wait for the job to be cancelled. Potentially a slow operation,
      # e.g. 10 seconds plus.
      # @param analysis_job_item [::AnalysisJobsItem]
      # @return [::Dry::Monads::Result<string>,nil]
      def cancel_job(analysis_job_item)
        return Success('Nothing to cancel') if analysis_job_item.queue_id.nil?

        connection.cancel_job(analysis_job_item.queue_id, wait: true)
      end

      # Remove a job from the job history on the cluster.
      # @param analysis_job_item [::AnalysisJobsItem]
      # @return [::Dry::Monads::Result<string>,nil]
      def clear_job(analysis_job_item)
        return Success('Nothing to cancel') if analysis_job_item.queue_id.nil?

        connection.cancel_job(analysis_job_item.queue_id, completed: true, force: true)
      end

      # Check the status of a job on the cluster.
      # @param analysis_job_item [::AnalysisJobsItem]
      # @return [::BawWorkers::BatchAnalysis::Models::JobStatus] the job status
      def job_status(analysis_job_item)
        raise ArgumentError, 'Analysis job item must have a queue id' if analysis_job_item.queue_id.nil?

        queue_id = analysis_job_item.queue_id
        status = connection.fetch_status(queue_id)

        convert_status(status)
      end

      # Parse a job status payload that we received from some other source
      # i.e. saved in a database or sent via a web hook.
      # @param raw_status [String,Hash] the raw payload or a JSON decoded hash of the payload
      # @return [::BawWorkers::BatchAnalysis::Models::JobStatus] the job status
      def parse_job_status(raw_status)
        job_list = connection.parse_status_payload(raw_status)

        convert_status(Success(job_list))
      end

      # Run a script on an audio recording by submitting the script to a cluster.
      # @param analysis_job_item [::AnalysisJobsItem] the script execute
      # @return [::Dry::Monads::Result<string>] the created job id
      def submit_job(analysis_job_item)
        analysis_job = analysis_job_item.analysis_job
        audio_recording = analysis_job_item.audio_recording
        script = analysis_job_item.script
        # But we use harvester to download audio and update job status
        #   - because if we used user for status, then users could update the status of the
        #     jobs improperly by any valid api call
        #   - and we need to use harvester for download otherwise download can
        #     fail if the user/project doesn't have the allow_original_download permission.
        #     This shouldn't be a big issue because users can't create analysis_jobs_items
        #     that they don't have access to, nor download any results they don't
        #     have access to.
        harvester_id = User.harvester_user.id

        prepared_script = prepare_script(analysis_job, script, audio_recording, harvester_id)
        working_directory = submit_directory(analysis_job_item)
        #        debugger
        # transform resource requirements to a simple hash (this step allows
        # resources to scale with the size of the input recording)
        resources = script.resources.combine(BASE_RESOURCES).calculate(
          recording_duration: audio_recording.duration_seconds,
          recording_size: audio_recording.data_length_bytes,
          minimums: MINIMUM_RESOURCES
        )

        report_start_script = curl_status_update(
          harvester_id,
          analysis_job.id,
          analysis_job_item.id,
          AnalysisJobsItem::STATUS_WORKING
        )

        report_finish_script = curl_status_update(
          harvester_id,
          analysis_job.id,
          analysis_job_item.id,
          AnalysisJobsItem::TRANSITION_FINISH
        )

        report_error_script = curl_status_update(
          harvester_id,
          analysis_job.id,
          analysis_job_item.id,
          AnalysisJobsItem::TRANSITION_FINISH
        )

        connection
          .submit_job(
            prepared_script,
            working_directory,
            job_name: analysis_job_item.id.to_s,
            report_error_script:,
            report_finish_script:,
            report_start_script:,
            env: {
              # TODO?
            },
            resources:,
            # hide the job script from the results endpoint by making it a dot file
            hidden: true
          )
      end

      private

      # @param value [::Dry::Monads::Result<::PBS::Models::Job>]
      # @return [::BawWorkers::BatchAnalysis::Models::JobStatus]
      def convert_status(value)
        Models::JobStatus.create(:pbs, value)
      end

      # Creates an output directory for the analysis job.
      # @param analysis_jobs_item [AnalysisJobItem]
      # @return [Pathname]
      def submit_directory(analysis_jobs_item)
        analysis_jobs_item.results_absolute_path
      end

      def status_jwt(harvester_id)
        # attempted to cache the value here but it messed up tests because
        # the encoded values can refer to users that no longer exist
        #debugger
        Api::Jwt.encode(
          subject: harvester_id,
          expiration: settings.auth_tokens_expire_in.seconds,
          resource: :analysis_jobs_items,
          action: :invoke
        )
      end

      def download_jwt(creator_id)
        # attempted to cache the value here but it messed up tests because
        # the encoded values can refer to users that no longer exist
        Api::Jwt.encode(
          subject: creator_id,
          expiration: settings.auth_tokens_expire_in.seconds,
          resource: :media,
          action: :original
        )
      end

      # Used for working and completed status updates
      def curl_status_update(harvester_id, analysis_job_id, analysis_jobs_item_id, status)
        endpoint = @url_helpers.invoke_analysis_job_item_url(
          analysis_job_id:,
          id: analysis_jobs_item_id,
          invoke_action: status
        )

        token = status_jwt(harvester_id)
        # https://curl.se/docs/manpage.html
        # write-out '\\n' is required to get a newline after the output otherwise
        # the next command will be appended to the end of the output
        # ! Will not follow redirects.
        # We don't expect redirects are needed but if they are here curl semantics mean
        # it would fire a GET instead of a POST after redirect unless we customize the behaviour.
        # rubocop:disable Style/FormatStringToken
        command = <<~SHELL
          curl
          --silent
          --show-error
          --header 'Accept: application/json'
          --header 'Content-Type: application/json'
          --header 'Authorization: Bearer #{token}'
          --request POST
          --retry 3
          --fail-with-body
          --write-out '\\nStatus update: %{http_code} in %{time_total} seconds\\n'
          "#{endpoint}"
        SHELL
        # rubocop:enable Style/FormatStringToken

        command.squish
      end

      def curl_audio_download(harvester_id, audio_recording_id, source_dir, canonical_name)
        endpoint = @url_helpers.audio_recording_media_original_url(audio_recording_id:)
        token = download_jwt(harvester_id)
        # https://curl.se/docs/manpage.html
        # write-out '\\n' is required to get a newline after the output otherwise
        # the next command will be appended to the end of the output
        # Will follow redirects, retry on all errors, and retry 3 times.
        # rubocop:disable Style/FormatStringToken
        command = <<~SHELL
          curl
          --silent
          --show-error
          --header 'Authorization: Bearer #{token}'
          --output-dir "#{source_dir}"
          --output "#{canonical_name}"
          --http1.1 --retry #{DOWNLOAD_ATTEMPTS} --retry-all-errors --fail --retry-delay #{DOWNLOAD_RETRY}
          --location
          --write-out '\\nFile downloaded: %{http_code} (exitcode: %{exitcode}) %{filename_effective} %{size_download} bytes %{speed_download} bytes/s %{time_total} seconds\\n'
          "#{endpoint}"
        SHELL
        # rubocop:enable Style/FormatStringToken

        command.squish
      end

      # @param analysis_job [AnalysisJob]
      # @param script [Script]
      # @param audio_recording [AudioRecording]
      # @param harvester_id [Integer]
      # @return [String] the script fragment
      def prepare_script(analysis_job, script, audio_recording, harvester_id)
        command = script.executable_command
        output = WORKING_DIR
        source_name = audio_recording.friendly_name
        config_name = script.executable_settings_name

        download_command = curl_audio_download(
          harvester_id,
          audio_recording.id,
          SOURCE_DIR,
          source_name
        )

        analysis_job
          .analysis_jobs_scripts
          .find_by(script_id: script.id)
          .custom_settings => custom_settings
        encoded_config = format_config(
          (custom_settings.presence || script.executable_settings),
          config_name
        )

        command = CommandTemplater.format_command(command, {
          source_dir: SOURCE_DIR,
          config_dir: CONFIG_DIR,
          output_dir: output,
          temp_dir: TEMP_DIR,
          source_basename: source_name,
          config_basename: config_name,
          source: SOURCE_DIR / source_name,
          config: CONFIG_DIR / config_name,
          latitude: audio_recording.site.latitude,
          longitude: audio_recording.site.longitude,
          timestamp: audio_recording.recorded_date,
          id: audio_recording.id,
          uuid: audio_recording.uuid
        })

        <<~SHELL
          # download source audio
          log "Downloading source audio..."
          mkdir -p "#{SOURCE_DIR}"
          #{download_command}

          # emit config file
          log "Writing config file..."
          mkdir -p "#{CONFIG_DIR}"
          #{encoded_config}

          # make temp dir
          log "Creating temp dir..."
          mkdir -p "#{TEMP_DIR}"

          # switch back to output dir
          log "Switching to output dir #{WORKING_DIR}..."
          cd #{output}

          log "Running command..."
          # run command
          #{command}

          log "Done."
        SHELL
      end

      # @param config [String]
      # @param name [String]
      # @return [String]
      def format_config(config, name)
        return '' if config.blank?

        # embed the config in a safe way - you can't break out of an encoding
        encoded = Base64.encode64(config)
        config_delimiter = "CONFIG#{Random.alphanumeric(64)}"

        # https://linuxize.com/post/bash-heredoc/
        <<~SHELL
          cat <<-#{config_delimiter} | base64 --decode > "#{CONFIG_DIR}/#{name}"
          #{encoded}
          #{config_delimiter}
        SHELL
      end
    end
  end
end
