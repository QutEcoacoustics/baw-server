module BawWorkers
  module Analysis
    # Runs analysis scripts on audio files.
    class Action < BawWorkers::ActionBase

      # All methods do not require a class instance.
      class << self

        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.actions.analysis.queue
        end

        # Perform analysis on a single file. Used by resque.
        # @param [Hash] analysis_params
        # @return [Hash] result information
        def action_perform(analysis_params)
          analysis_params_sym = BawWorkers::Analysis::Payload.normalise_opts(analysis_params)

          BawWorkers::Config.logger_worker.info(logger_name) {
            "Started analysis using '#{format_params_for_log(analysis_params_sym)}'."
          }

          runner = action_runner
          result = nil
          all_opts = nil

          begin
            prepared_opts = runner.prepare(analysis_params_sym)
            all_opts = analysis_params_sym.merge(prepared_opts)
            result = runner.execute(prepared_opts, analysis_params_sym)
          rescue => e
            BawWorkers::Config.logger_worker.error(logger_name) { e }

            args = analysis_params_sym
            args = all_opts unless all_opts.blank?
            args = {params: args, results: result} unless result.nil?

            BawWorkers::Mail::Mailer.send_worker_error_email(
                BawWorkers::Analysis::Action,
                args,
                queue,
                e
            )
            raise e
          end

          # if result contains error, raise it here, since we need everything in execute
          # to succeed first (so logs/configs are moved, any available results are retained)
          # raising here to not send email when executable fails, logs are in output dir
          if !result.blank? && result.include?(:error) && !result[:error].blank?
            BawWorkers::Config.logger_worker.error(logger_name) { result[:error] }
            raise result[:error]
          end

          BawWorkers::Config.logger_worker.info(logger_name) {
            log_opts = all_opts.blank? ? analysis_params_sym : all_opts
            "Completed analysis with parameters #{format_params_for_log(log_opts)} and result '#{format_params_for_log(result)}'."
          }

          result
        end

        # Perform analysis on a single file using a yaml file.
        # @param [String] analysis_params_file
        # @return [Hash] result information
        def action_perform_rake(analysis_params_file)
          path = BawWorkers::Validation.normalise_file(analysis_params_file)
          analysis_params = YAML.load_file(path)
          BawWorkers::Analysis::Action.action_perform(analysis_params)
        end

        # Perform analysis using details from a csv file.
        # @param [String] csv_file
        # @param [String] config_file
        # @param [String] command_file
        # @return [Hash] result information
        def action_perform_rake_csv(csv_file, config_file, command_file)

          payloads = action_payload.from_csv(csv_file, config_file, command_file)

          results = []
          payloads.each do |payload|
            begin
              result = BawWorkers::Analysis::Action.action_perform(payload)
              results.push(result)
            rescue => e
              BawWorkers::Config.logger_worker.error(logger_name) { e }
            end
          end

          results
        end

        # Enqueue an analysis request.
        # @param [Hash] analysis_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(analysis_params)
          analysis_params_sym = BawWorkers::Analysis::Payload.normalise_opts(analysis_params)
          result = BawWorkers::Analysis::Action.create(analysis_params: analysis_params_sym)
          BawWorkers::Config.logger_worker.info(logger_name) {
            "Job enqueue returned '#{result}' using #{format_params_for_log(analysis_params_sym)}."
          }
          result
        end

        # Enqueue an analysis request using a single file via an analysis config file.
        # @param [String] single_file_config
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue_rake(single_file_config)
          path = BawWorkers::Validation.normalise_file(single_file_config)
          config = YAML.load_file(path)
          BawWorkers::Analysis::Action.action_enqueue(config)
        end

        # Enqueue an analysis request using information from a csv file.
        # @param [String] csv_file
        # @param [String] config_file
        # @param [String] command_file
        # @return [<Array<Boolean>] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue_rake_csv(csv_file, config_file, command_file)

          payloads = action_payload.from_csv(csv_file, config_file, command_file)

          results = []
          payloads.each do |payload|
            begin
              result = BawWorkers::Analysis::Action.action_enqueue(payload)
              results.push(result)
            rescue => e
              BawWorkers::Config.logger_worker.error(logger_name) { e }
            end
          end
          results
        end

        # Create a BawWorkers::Analysis::Runner instance.
        # @return [BawWorkers::Analysis::Runner]
        def action_runner
          BawWorkers::Analysis::Runner.new(
              BawWorkers::Config.original_audio_helper,
              BawWorkers::Config.analysis_cache_helper,
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.worker_top_dir,
              BawWorkers::Config.programs_dir)
        end

        def action_payload
          BawWorkers::Analysis::Payload.new(BawWorkers::Config.logger_worker)
        end

        # Get a Resque::Status hash for if an analysis job has a matching payload.
        # @param [Hash] analysis_params
        # @return [Resque::Plugins::Status::Hash] status
        def get_job_status(analysis_params)
          analysis_params_sym = BawWorkers::Analysis::Payload.normalise_opts(analysis_params)
          payload = {analysis_params: analysis_params_sym}
          BawWorkers::ResqueApi.status(BawWorkers::Analysis::Action, payload)
        end

        private

        def format_params_for_log(params)
          if params.blank? || !params.is_a?(Hash)
            return params
          end
          if params.include?(:config)
            params.except(:config)
          else
            params
          end
        end

      end

      def perform_options_keys
        ['analysis_params']
      end

    end
  end
end