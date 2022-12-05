# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Runs analysis scripts on audio files.
      class Job < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.analysis.queue
        perform_expects Integer

        # @return [::AnalysisJobsItem] The database record for the current job item
        attr_reader :analysis_job_item

        # Perform analysis on a single file. Used by resque.
        # @param analysis_job_item_id [Integer]
        def perform(analysis_job_item_id)
          load_records(analysis_job_item_id)

          analysis_params_sym = BawWorkers::Jobs::Analysis::Payload.normalize_opts(analysis_params)

          BawWorkers::Config.logger_worker.info do
            { message: 'Started analysis', parameters: Job.format_params_for_log(analysis_params_sym) }
          end

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
          rescue BawWorkers::Exceptions::ActionCancelledError => e
            final_status = :cancelled

            # if killed legitimately don't email
            BawWorkers::Config.logger_worker.warn do
              "Analysis cancelled: '#{e}'"
            end
            raise
          rescue StandardError => e
            final_status = :failed
            raise
          ensure
            # run no matter what
            # update our action tracker
            status_updater.end(analysis_params_sym, final_status) unless final_status.blank?
          end

          # if result contains error, raise it here, since we need everything in execute
          # to succeed first (so logs/configs are moved, any available results are retained)
          # raising here to not send email when executable fails, logs are in output dir
          if !result.blank? && result.include?(:error) && !result[:error].blank?
            BawWorkers::Config.logger_worker.error { result[:error] }
            raise result[:error]
          end

          BawWorkers::Config.logger_worker.info do
            log_opts = all_opts.blank? ? analysis_params_sym : all_opts
            "Completed analysis with parameters #{Job.format_params_for_log(log_opts)} and result '#{Job.format_params_for_log(result)}'."
          end

          result
        end

        # @return [::AnalysisJobsItem]
        def load_records(analysis_job_item_id)
          aji = AnalysisJobItem.find(analysis_job_item_id)

          @analysis_job_item = aji
        end

        # Enqueue an analysis request.
        # @param [Hash] analysis_params
        # @return [String] An unique key for the job if enqueuing was successful.
        # payloads to work. Must be common to all payloads in a group.
        def self.action_enqueue(analysis_params, job_class = nil)
          BawWorkers::Config.logger_worker.info('args', analysis_params:, job_class:)
          analysis_params_sym = BawWorkers::Jobs::Analysis::Payload.normalize_opts(analysis_params)

          job_class ||= BawWorkers::Jobs::Analysis::Job
          job = job_class.new(analysis_params_sym)

          result = job.enqueue != false
          BawWorkers::Config.logger_worker.info do
            "#{job_class} enqueue returned '#{result}' using #{format_params_for_log(analysis_params_sym)}."
          end

          job.job_id
        end

        # Create a BawWorkers::Jobs::Analysis::Runner instance.
        # @return [BawWorkers::Jobs::Analysis::Runner]
        def action_runner
          BawWorkers::Jobs::Analysis::Runner.new(
            BawWorkers::Config.original_audio_helper,
            BawWorkers::Config.analysis_cache_helper,
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.worker_top_dir,
            BawWorkers::Config.programs_dir
          )
        end

        # @return [BawWorkers::Jobs::Analysis::Status]
        def action_status_updater
          @action_status_updater ||= BawWorkers::Jobs::Analysis::Status.new(BawWorkers::Config.api_communicator)
        end

        def action_payload
          BawWorkers::Jobs::Analysis::Payload.new(BawWorkers::Config.logger_worker)
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          id = arguments&.first&.fetch(:id)
          job_id = arguments&.first&.fetch(:job_id)
          "Analysis for: #{id}, job=#{job_id}"
        end

        private

        # Note, the status symbols returned adhere to the states of an baw-server `AnalysisJobItem`
        def status_from_result(result)
          return :failed if result.nil?

          if result.include?(:error) && !result[:error].nil?
            return :timed_out if result[:error].is_a?(BawAudioTools::Exceptions::AudioToolTimedOutError)

            return :failed
          end

          :successful
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'analysis_job')
        end
      end
    end
  end
end
