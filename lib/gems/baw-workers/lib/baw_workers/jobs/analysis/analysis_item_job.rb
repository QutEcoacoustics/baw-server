# frozen_string_literal: true
# # frozen_string_literal: true

# module BawWorkers
#   module Jobs
#     module Analysis
#       # Runs analysis scripts on audio files.
#       class AnalysisItemJob < BawWorkers::Jobs::ApplicationJob
#         queue_as Settings.actions.analysis.queue
#         perform_expects Integer

#         class << self
#           # Enqueue a job to run analysis on a single file.
#           # @param analysis_job_item [AnalysisJobsItem]
#           # @return [Boolean] true if the job was enqueued, false if it was not
#           def enqueue(analysis_job_item)
#             unless analysis_job_item.is_a?(::AnalysisJobsItem)
#               raise "Must be an AnalysisJobsItem, not #{analysis_job_item.class}"
#             end

#             result = perform_later(analysis_job_item.id) { |job|
#               next if job.successfully_enqueued?
#               # if the enqueue fails because the job is already in the queue then we don't care
#               # otherwise throw an error
#               raise "Failed to enqueue harvest item with id #{id}" if job.unique?
#             }

#             result != false
#           end
#         end

#         # @return [::AnalysisJobsItem] The database record for the current job item
#         attr_reader :analysis_job_item

#         # @return [::AnalysisJob] The database record for the current job
#         attr_reader :analysis_job

#         # Perform analysis on a single file. Used by resque.
#         # @param analysis_job_item_id [Integer]
#         def perform(analysis_job_item_id)
#           begin
#             load_records(analysis_job_item_id)

#             # analysis_params_sym = BawWorkers::Jobs::Analysis::Payload.normalize_opts(analysis_params)

#             logger.info('Started analysis enqueue')

#             # check if should cancel
#             kill_if_cancelled!

#             #communicator.run_system_script
#             communicator.connection.

#               prepared_opts = runner.prepare(analysis_params_sym)
#             all_opts = analysis_params_sym.merge(prepared_opts)
#             result = runner.execute(prepared_opts, analysis_params_sym)

#             final_status = status_from_result(result)
#           rescue BawWorkers::Exceptions::ActionCancelledError => e
#             final_status = :cancelled

#             # if killed legitimately don't email
#             logger.warn do
#               "Analysis cancelled: '#{e}'"
#             end
#             raise
#           rescue StandardError => e
#             final_status = :failed
#             raise
#           ensure
#             # run no matter what
#             # update our action tracker
#             status_updater.end(analysis_params_sym, final_status) unless final_status.blank?
#           end

#           # if result contains error, raise it here, since we need everything in execute
#           # to succeed first (so logs/configs are moved, any available results are retained)
#           # raising here to not send email when executable fails, logs are in output dir
#           if !result.blank? && result.include?(:error) && !result[:error].blank?
#             logger.error { result[:error] }
#             raise result[:error]
#           end

#           logger.info do
#             log_opts = all_opts.blank? ? analysis_params_sym : all_opts
#             "Completed analysis with parameters #{Job.format_params_for_log(log_opts)} and result '#{Job.format_params_for_log(result)}'."
#           end

#           result
#         end

#         private

#         # @return [::AnalysisJobsItem]
#         def load_records(analysis_job_item_id)
#           aji = AnalysisJobItem.find(analysis_job_item_id)

#           @analysis_job_item = aji
#           @analysis_job = aji.analysis_job
#         end

#         # The batch analysis service.
#         # @return [BawWorkers::BatchAnalysis::Communicator]
#         def communicator
#           @communicator ||= BawWorkers::Config.batch_analysis
#         end

#         def kill_if_cancelled!
#           return if analysis_job_item.cancelling? || analysis_job.cancelled?

#           kill!
#         end

#         def on_killed
#           analysis_job_item.confirm_cancel if analysis_job_item.may_confirm_cancel?
#         end

#         # # Enqueue an analysis request.
#         # # @param [Hash] analysis_params
#         # # @return [String] An unique key for the job if enqueuing was successful.
#         # # payloads to work. Must be common to all payloads in a group.
#         # def self.action_enqueue(analysis_params, job_class = nil)
#         #   logger.info('args', analysis_params:, job_class:)
#         #   analysis_params_sym = BawWorkers::Jobs::Analysis::Payload.normalize_opts(analysis_params)

#         #   job_class ||= BawWorkers::Jobs::Analysis::Job
#         #   job = job_class.new(analysis_params_sym)

#         #   result = job.enqueue != false
#         #   logger.info do
#         #     "#{job_class} enqueue returned '#{result}' using #{format_params_for_log(analysis_params_sym)}."
#         #   end

#         #   job.job_id
#         # end

#         # # Create a BawWorkers::Jobs::Analysis::Runner instance.
#         # # @return [BawWorkers::Jobs::Analysis::Runner]
#         # def action_runner
#         #   BawWorkers::Jobs::Analysis::Runner.new(
#         #     BawWorkers::Config.original_audio_helper,
#         #     BawWorkers::Config.analysis_cache_helper,
#         #     logger,
#         #     BawWorkers::Config.worker_top_dir,
#         #     BawWorkers::Config.programs_dir
#         #   )
#         # end

#         # def action_payload
#         #   BawWorkers::Jobs::Analysis::Payload.new(logger)
#         # end

#         # Produces a sensible name for this payload.
#         # Should be unique but does not need to be. Has no operational effect.
#         # This value is only used when the status is updated by resque:status.
#         def name
#           id = arguments&.first
#           "Analysis job item : #{id}"
#         end

#         # # Note, the status symbols returned adhere to the states of an baw-server `AnalysisJobItem`
#         # def status_from_result(result)
#         #   return :failed if result.nil?

#         #   if result.include?(:error) && !result[:error].nil?
#         #     return :timed_out if result[:error].is_a?(BawAudioTools::Exceptions::AudioToolTimedOutError)

#         #     return :failed
#         #   end

#         #   :successful
#         # end

#         def create_job_id
#           # duplicate jobs should be detected
#           ::BawWorkers::ActiveJob::Identity::Generators.generate_keyed_id(self, {
#             analysis_job: arguments&.first
#           })
#         end
#       end
#     end
#   end
# end
