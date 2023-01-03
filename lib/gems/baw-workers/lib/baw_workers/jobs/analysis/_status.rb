# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Analysis
      # Integrates an Analysis action with our tracking systems
      # The broader resque:status concerns are handled higher up the hierarchy
      class Status
        def initialize(api_communicator)
          @api_communicator = api_communicator

          # sign into the website
          @security_info = get_security_info
        end

        # @param [Hash] params
        def begin(params)

          analysis_job_id = params[:job_id]
          audio_recording_id = params[:id]

          # check if job has been killed by website tracking
          cancel_result = try_update('Could not check AnalysisJobsItems status.') {
            @api_communicator.get_analysis_jobs_item_status(
              analysis_job_id,
              audio_recording_id,
              @security_info
            )
          }
          cancelled_by_website = cancel_result[:status].nil? ? false : cancel_result[:status].to_sym == :cancelling

          # if it has been cancelled
          if cancelled_by_website
            # raise an action cancelled exception - it will be caught by action_perform
            BawWorkers::Config.logger_worker.warn(self.class.name) do
              'The website cancelled this analysis job'
            end
            raise BawWorkers::Exceptions::ActionCancelledError, cancel_result[:response_json]
          end

          working_json = try_update('Could not update AnalysisJobsItems status to :working.') {
            @api_communicator.update_analysis_jobs_item_status(
              analysis_job_id,
              audio_recording_id,
              :working,
              @security_info
            )
          }

          raise  BawWorkers::Exceptions::AnalysisEndpointError, working_json[:response] if working_json[:failed]
        end

        # Update the tracking system. At this point the status is either cancelled, timed_out, successful, or failed
        # @param [Symbol] status
        # @param [Hash] params
        def end(params, status)

          analysis_job_id = params[:job_id]
          audio_recording_id = params[:id]

          # NB: no need to update redis status. It does it automatically

          try_update("Could not update AnalysisJobsItems status to #{status}.") do
            @api_communicator.update_analysis_jobs_item_status(analysis_job_id, audio_recording_id, status,
              @security_info)
          end
        end

        def self.retry_attempts
          4
        end

        def try_update(*context)
          retry_attempts = self.class.retry_attempts
          attempts_left = retry_attempts
          failed = false
          errors = []
          while attempts_left.positive?
            # = 0.0, ~1.718, ~6.389, ~19.085
            back_off = Math.exp(retry_attempts - attempts_left) - 1
            sleep(back_off)

            # update website with desired status
            # the API communicator heavily logs what is is doing
            result = nil
            begin
              result = yield
            rescue StandardError => e
              errors << e
              failed = true
            end

            return result unless failed || result[:failed]

            attempts_left -= 1
            @api_communicator.logger.warn(self.class.name) {
              "AnalysisJobItem status update failed, trying again, #{attempts_left} attempts left"
            }
          end

          # the web request has failed multiple times
          error = BawWorkers::Exceptions::AnalysisEndpointError.new("#{context}\n#{errors.map(&:message).join("\n")}")
          raise error
        end

        def get_security_info
          security_info = try_update('Could not log in.') {
            @api_communicator.request_login
          }
        end

      end
    end
  end
end
