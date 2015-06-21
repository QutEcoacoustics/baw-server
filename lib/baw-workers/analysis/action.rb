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
          analysis_params_sym = BawWorkers::Analysis::WorkHelper.validate(analysis_params)

          BawWorkers::Config.logger_worker.info(self.name) {
            "Started analysis using '#{analysis_params_sym}'."
          }

          runner = action_helper
          result = nil
          begin
            result = runner.run(analysis_params_sym)
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
                BawWorkers::Analysis::Action,
                analysis_params_sym,
                queue,
                e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            "Completed analysis with result '#{result}'."
          }

          result
        end

        # Perform analysis on a single file.
        # @param [String] single_file_config
        # @return [Hash] result information
        def action_perform_rake(single_file_config)
          path = BawWorkers::Validation.validate_file(single_file_config)
          config = YAML.load_file(path)
          BawWorkers::Analysis::Action.action_perform(config)
        end

        # Perform analysis using details from a csv file.
        # @param [String] csv_file
        # @param [String] template_file
        # @return [Hash] result information
        def action_perform_rake_csv(csv_file, template_file)
          csv_path = BawWorkers::Validation.validate_file(csv_file)
          template_path = BawWorkers::Validation.validate_file(template_file)
          audio_recording_configs = action_helper.csv_to_config(csv_path, template_path)

          results = []
          audio_recording_configs.each do |audio_recording_config|
            results.push(BawWorkers::Analysis::Action.action_perform(audio_recording_config))
          end

          results
        end

        # Enqueue an analysis request.
        # @param [Hash] analysis_params
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue(analysis_params)
          analysis_params_sym = BawWorkers::Analysis::WorkHelper.validate(analysis_params)
          result = BawWorkers::Analysis::Action.create(analysis_params: analysis_params_sym)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using #{analysis_params_sym}."
          }
          result
        end

        # Enqueue an analysis request using a single file via an analysis config file.
        # @param [String] single_file_config
        # @return [Boolean] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue_rake(single_file_config)
          path = BawWorkers::Validation.validate_file(single_file_config)
          config = YAML.load_file(path)
          BawWorkers::Analysis::Action.action_enqueue(config)
        end

        # Enqueue an analysis request using information from a csv file.
        # @param [String] csv_file
        # @param [String] template_file
        # @return [<Array<Boolean>] True if job was queued, otherwise false. +nil+
        #   if the job was rejected by a before_enqueue hook.
        def action_enqueue_rake_csv(csv_file, template_file)
          csv_path = BawWorkers::Validation.validate_file(csv_file)
          template_path = BawWorkers::Validation.validate_file(template_file)
          audio_recording_configs = action_helper.csv_to_config(csv_path, template_path)

          results = []
          audio_recording_configs.each do |audio_recording_config|
            results.push(BawWorkers::Analysis::Action.action_enqueue(audio_recording_config))
          end
          results
        end

        # Create a BawWorkers::Analysis::WorkHelper instance.
        # @return [BawWorkers::Analysis::WorkHelper]
        def action_helper
          BawWorkers::Analysis::WorkHelper.new(
              BawWorkers::Config.original_audio_helper,
              BawWorkers::Config.analysis_cache_helper,
              BawWorkers::Config.logger_worker,
              BawWorkers::Config.temp_dir
          )
        end

        # Get a Resque::Status hash for if an analysis job has a matching payload.
        # @param [Hash] analysis_params
        # @return [Resque::Plugins::Status::Hash] status
        def get_job_status(analysis_params)
          analysis_params_sym = BawWorkers::Analysis::WorkHelper.validate(analysis_params)
          payload = {analysis_params: analysis_params_sym}
          BawWorkers::ResqueApi.status(BawWorkers::Analysis::Action, payload)
        end

      end

      def perform_options_keys
        ['analysis_params']
      end

    end
  end
end