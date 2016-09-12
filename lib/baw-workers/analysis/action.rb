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
          status_updater = action_status_updater
          result = nil
          all_opts = nil
          final_status = nil

          begin
            # check if should cancel, if we should raises Resque::Plugins::Status::Killed
            status_updater.begin(analysis_params_sym)

            prepared_opts = runner.prepare(analysis_params_sym)
            all_opts = analysis_params_sym.merge(prepared_opts)
            result = runner.execute(prepared_opts, analysis_params_sym)

            final_status = status_from_result(result)
          rescue BawWorkers::Exceptions::ActionCancelledError => ace
            final_status = :cancelled

            # if killed legitimately don't email
            BawWorkers::Config.logger_worker.warn(logger_name) {
              "Analysis cancelled: '#{ace}'"
            }
            raise ace
          rescue => e
            final_status = :failed
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
          ensure
            # run no matter what
            # update our action tracker
            status_updater.end(analysis_params_sym, final_status) unless final_status.blank?
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
        # @return [String] An unique key for the job (a UUID) if enqueuing was successful.
        # @param [String] invariant_group_key - a token used to group invariant payloads. Must be provided for partial
        # payloads to work. Must be common to all payloads in a group.
        def action_enqueue(analysis_params, invariant_group_key = nil)

          analysis_params_sym = BawWorkers::Analysis::Payload.normalise_opts(analysis_params)

          # split and validate the invariant params
          # no-op id invariant_group_key is blank
          analysis_params_sym = BawWorkers::Analysis::Payload.validate_and_create_invariant_opts(
              analysis_params_sym,
              invariant_group_key)

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

          # enable partial payloads - group everything from this CSV batch together
          group_key = Date.today.to_time.to_i.to_s

          results = []
          payloads.each do |payload|
            begin
              result = BawWorkers::Analysis::Action.action_enqueue(payload, group_key)
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

        # @return [BawWorkers::Analysis::Status]
        def action_status_updater
          BawWorkers::Analysis::Status.new(BawWorkers::Config.api_communicator)
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

        # Note, the status symbols returned adhere to the states of an baw-server `AnalysisJobItem`
        def status_from_result(result)
          return :failed if result.nil?
          if result.include?(:error) && !result[:error].nil?
            return :timed_out if result[:error].is_a?(BawAudioTools::Exceptions::AudioToolTimedOutError)
            return :failed
          end

          :successful
        end

      end

      #
      # Instance methods
      #

      def perform_options_keys
        ['analysis_params']
      end

      # Produces a sensible name for this payload.
      # Should be unique but does not need to be. Has no operational effect.
      # This value is only used when the status is updated by resque:status.
      def name
        ap = @options['analysis_params']
        "Analysis for #{ap['id']}, job=#{ap['job_id']}"
      end

    end
  end
end