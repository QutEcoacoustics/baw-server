# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    # Starts analyses on a compute cluster.
    class Communicator
      COMMAND_PLACEHOLDERS = Set.new([
        # absolute path to source audio file
        :source,
        # absolute path to the config file
        :config,
        # absolute path to output dir (is also created)
        :output,
        # absolute path to temp dir (is also created)
        :temp
      ]).freeze

      REQUIRED_COMMAND_PLACEHOLDERS = Set.new([
        :source,
        :output
      ]).freeze

      # scratch is cleaned automatically by PBS
      SCRATCH_DIR = Pathname(PBS::Connection::ENV_TMPDIR)

      # wherever the job file is submitted from, we use this as our
      # working directory and output directory
      WORKING_DIR = Pathname(PBS::Connection::ENV_PBS_O_WORKDIR)

      # these resources are all cleaned after a job run by PBS
      CONFIG_DIR = SCRATCH_DIR / 'config'
      SOURCE_DIR = SCRATCH_DIR / 'source'
      TEMP_DIR = SCRATCH_DIR / 'tmp'

      include Api::UrlHelpers

      # @return [PBS::Connection]
      attr_reader :connection

      # @return [BawApp::BatchAnalysisSettings]
      attr_reader :settings

      # @return [BawWorkers::Storage::AnalysisCache]
      attr_reader :analysis_cache_helper

      def initialize
        @settings = Settings.batch_analysis
        @connection = PBS::Connection.new(settings)
        @analysis_cache_helper = BawWorkers::Config.analysis_cache_helper
      end

      # Removes a job from the cluster queue.
      # @param analysis_job_item [::AnalysisJobsItem]
      # @return [::Dry::Monads::Result<string>]
      def cancel_job(analysis_job_item)
        connection.cancel_job(analysis_job_item.queue_id)
      end

      # Run a script on an audio recording by submitting the script to a cluster.
      # @param analysis_jobs_item [::AnalysisJobsItem] the script execute
      # @return [::Dry::Monads::Result<string>]
      def submit_job(analysis_job_item)
        analysis_job = analysis_job_item.analysis_job
        audio_recording = analysis_job_item.audio_recording
        creator = analysis_job.creator

        script = prepare_script(analysis_job, analysis_job.script, audio_recording, creator)
        working_directory = submit_directory(analysis_job, audio_recording)
        # hide the job from the results endpoint by making it a dot file
        job_name = ".#{analysis_job_item.id}"

        connection.submit_job(
          script,
          working_directory,
          job_name:,
          report_error_script: curl_status_update(creator, analysis_job.id, audio_recording.id, 'failed'),
          report_finish_script: curl_status_update(creator, analysis_job.id, audio_recording.id, 'successful'),
          report_start_script: curl_status_update(creator, analysis_job.id, audio_recording.id, 'working'),
          env: {
            # TODO?
          },
          resources: {
            # TODO?
            # Just using all default values for now, we don't have a mechanism to read this from the analysis
          }
        )
      end

      private

      # creates an output directory for the analysis job and makes sure it exists
      # @param analysis_job [AnalysisJob]
      # @param audio_recording [AudioRecording]
      # @return [Pathname]
      def submit_directory(analysis_job, audio_recording)
        analysis_cache_helper
          .possible_paths_dir({
            job_id: analysis_job.id,
            uuid: audio_recording.uuid,
            sub_folders: []
          })
          .first => path

        path = Pathname(path)
        path.mkpath

        path
      end

      def status_jwt(creator)
        @status_jwt ||= Api::Jwt.encode(
          subject: creator.id,
          expiration: settings.auth_tokens_expire_in.seconds,
          resource: :analysis_jobs_items,
          action: :update
        )
      end

      def download_jwt(creator)
        @download_jwt ||= Api::Jwt.encode(
          subject: creator.id,
          expiration: settings.auth_tokens_expire_in.seconds,
          resource: :media,
          action: :original
        )
      end

      def curl_status_update(creator, analysis_job_id, audio_recording_id, status)
        endpoint = analysis_job_audio_recording_url(analysis_job_id:, audio_recording_id:)
        token = status_jwt(creator)
        # https://curl.se/docs/manpage.html
        command = <<~SHELL
          curl
          --silent
          --show-error
          --header 'Accept: application/json'
          --header 'Content-Type: application/json'
          --header 'Authorization: Bearer #{token}'
          --request PUT
          --json '{"analysis_jobs_item":{"status":"#{status}"}}'
          --retry 3
          #{endpoint}
        SHELL

        command.squish
      end

      def curl_audio_download(creator, audio_recording_id)
        endpoint = audio_recording_media_original_url(audio_recording_id:)
        token = download_jwt(creator)
        # https://curl.se/docs/manpage.html
        command = <<~SHELL
          curl
          --silent
          --show-error
          --header 'Authorization: Bearer #{token}'
          --remote-header-name
          --remote-name
          --retry 3
          #{endpoint}
        SHELL

        command.squish
      end

      # @param analysis_job [AnalysisJob]
      # @param script [Script]
      # @return [String] the script fragment
      def prepare_script(analysis_job, script, audio_recording, user)
        command = script.executable_command

        output = WORKING_DIR

        download_command = curl_audio_download(user, audio_recording.audio_recording_id)

        command = format_command(command, {
          source: SOURCE_DIR,
          config: CONFIG_DIR,
          output:,
          temp: TEMP_DIR
        })

        <<~SHELL
          # download source audio
          log "Downloading source audio..."
          mkdir -p #{SOURCE_DIR}
          cd #{SOURCE_DIR}
          #{download_command}

          # emit config file
          log "Writing config file..."
          mkdir -p #{CONFIG_DIR}
          #{format_config(analysis_job.custom_settings, script.executable_settings_name)}

          # make temp dir
          log "Creating temp dir..."
          mkdir -p #{TEMP_DIR}

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
          cat <<-#{config_delimiter} | base64 --decode > #{CONFIG_DIR}/#{name}
          #{encoded}
          #{config_delimiter}
        SHELL
      end

      # @param command [String]
      # @param options [Hash]
      # @return [String]
      def format_command(command, options)
        # extract placeholders
        placeholders = command.scan(/{(.*?)}/).flatten.map(&:to_sym).to_set

        raise ArgumentError, 'Invalid placeholders in command' unless placeholders.subset?(COMMAND_PLACEHOLDERS)

        unless REQUIRED_COMMAND_PLACEHOLDERS.subset?(placeholders)
          raise ArgumentError, 'Missing required placeholders in command'
        end

        # substitute placeholders for values
        formatted = command.dup
        placeholders.each do |placeholder|
          value = options.fetch(placeholder, nil)

          raise ArgumentError, "Missing value in options for placeholder #{placeholder}" if value.nil?

          formatted.gsub!("{#{placeholder}}", value)
        end

        formatted
      end
    end
  end
end
