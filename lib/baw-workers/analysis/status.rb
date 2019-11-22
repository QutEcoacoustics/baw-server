module BawWorkers
  module Analysis

    # Integrates an Analysis action with our tracking systems
    # The broader resque:status concerns are handled higher up the hierarchy
    class Status

      def initialize(api_communicator)

        @api_communicator = api_communicator

        # sign into the website
        @security_info = Status.get_security_info(@api_communicator)
      end

      # @param [Hash] params
      def begin(params)
        # is system job? then ignore - we have no status tracking
        return if should_not_process?(params)

        analysis_job_id = params[:job_id]
        audio_recording_id = params[:id]

        # check if job has been killed by website tracking
        cancel_result = @api_communicator.get_analysis_jobs_item_status(
            analysis_job_id,
            audio_recording_id,
            @security_info)
        cancelled_by_website = cancel_result[:status].nil? ? false : cancel_result[:status].to_sym == :cancelling


        # if it has been cancelled
        if cancelled_by_website
          # raise an action cancelled exception - it will be caught by action_perform
          BawWorkers::Config.logger_worker.warn(self.class.name) {
            "The website cancelled this analysis job"
          }
          raise BawWorkers::Exceptions::ActionCancelledError.new(cancel_result[:response_json])
        end

        working_json = @api_communicator.update_analysis_jobs_item_status(
            analysis_job_id,
            audio_recording_id,
            :working,
            @security_info)

        if working_json[:failed]
          raise AnalysisEndpointError.new(working_json[:response_json])
        end
      end


      # Update the tracking system. At this point the status is either cancelled, timed_out, successful, or failed
      # @param [Symbol] status
      # @param [Hash] params
      def end(params, status)
        # is system job? then ignore - we have no status tracking
        return if should_not_process?(params)

        analysis_job_id = params[:job_id]
        audio_recording_id = params[:id]

        # NB: no need to update resque status.
        # The `Resque:Plugins:Status::safe_perform!` method handles all of it's updates

        retry_attempts = self.class.retry_attempts
        attempts_left = retry_attempts
        failed = false
        while attempts_left > 0
          # = 0.0, ~1.718, ~6.389, ~19.085
          back_off = Math.exp(retry_attempts - attempts_left) - 1
          sleep(back_off)

          # update website with desired status
          # the API communicator heavily logs what is is doing
          begin
            result = @api_communicator.update_analysis_jobs_item_status(analysis_job_id, audio_recording_id, status, @security_info)
          rescue Timeout::Error => te
            # yeah we're squashing :-/ but this is all error handling code...
            failed = true
          end

          if failed || result[:failed]
            attempts_left = attempts_left - 1
            @api_communicator.logger.warn(self.class.name) {
              "AnalysisJobItem status update failed, trying again, #{attempts_left} attempts left"
            }
          else
            attempts_left = -1
          end
        end

        # the web request has failed multiple times
        if attempts_left == 0
          self.class.mail_error(params, status)
        end
      end

      private

      def self.retry_attempts
        4
      end

      def self.get_security_info(api_communicator)
        security_info = api_communicator.request_login

        if security_info.blank?
          msg = 'Could not log in.'
          @logger.error(@class_name) { msg }
          fail BawWorkers::Exceptions::AnalysisEndpointError, msg
        end

        security_info
      rescue => e
        self.class.mail_error(nil, nil, e)
        raise e
      end

      def should_not_process?(params)
        !params || params[:job_id].to_s.strip.downcase == BawWorkers::Storage::AnalysisCache::JOB_ID_SYSTEM
      end

      def self.mail_error(params, status, e = nil)
        BawWorkers::Mail::Mailer.send_worker_error_email(
            BawWorkers::Analysis::Status,
            {params: params, status: status},
            BawWorkers::Analysis::Action::queue,
            e || StandardError.new("Could not update AnalysisJobsItems status")
        )
      end
    end
  end
end

