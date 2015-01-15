module BawWorkers
  module Mirror
    # Copies files from one location to another.
    class Action

      # Ensure that there is only one job with the same payload per queue.
      # The default method to create a job ID from these parameters is to
      # do some normalization on the payload and then md5'ing it
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      # Jobs performed
      # Jobs enqueued
      # Jobs failed
      # Duration of last x jobs completed
      # Average job duration over last 100 jobs completed
      # Longest job duration over last 100 jobs completed
      # Jobs enqueued as timeseries data (minute, hour, day)
      # Jobs performed as timeseries data (minute, hour, day)
      extend Resque::Plugins::JobStats

      # track specific job instances and their status.
      # resque-status achieves this by giving job instances UUID's
      # and allowing the job instances to report their
      # status from within their iterations.
      include Resque::Plugins::Status

      # include common methods
      # must be the last include/extend so it can override methods
      include BawWorkers::ActionCommon

      class << self

        # By default, lock_after_execution_period is 0 and enqueued? becomes
        # false as soon as the job is being worked on.
        # The lock_after_execution_period setting can be used to delay when
        # the unique job key is deleted (i.e. when enqueued? becomes false).
        # For example, if you have a long-running unique job that takes around
        # 10 seconds, and you don't want to requeue another job until you are
        # sure it is done, you could set lock_after_execution_period = 20.
        # Or if you never want to run a long running job more than once per
        # minute, set lock_after_execution_period = 60.
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque. Overrides resque-status class method.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.actions.mirror.queue
        end

        # Perform work. Used by Resque.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [Boolean] true if successfully copied
        def action_perform(source, destinations)

          BawWorkers::Config.logger_worker.info(self.name) {
            "Started mirroring from #{source} to '#{destinations}'."
          }

          begin
            source_file, destination_files = action_validate(source, destinations)
            result = BawWorkers::Config.file_info.copy_to_many(source_file, destination_files)
          rescue Exception => e
            BawWorkers::Config.logger_worker.error(self.name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
                BawWorkers::Mirror::Action,
                {source: source, destinations: destinations},
                queue,
                e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            "Completed mirror with result '#{result}'."
          }

          result
        end

        # Enqueue a file mirror request.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [void]
        def action_enqueue(source, destinations)
          source_file, destination_files = action_validate(source, destinations)
          result = BawWorkers::Mirror::Action.create(source: source_file, destinations: destination_files)
          BawWorkers::Config.logger_worker.info(self.name) {
            "Job enqueue returned '#{result}' using source #{source_file} and destinations #{destination_files.join(', ')}."
          }
          result
        end

        # Validate that source and destinations are paths, and are compatible with each other.
        def action_validate(source, destinations)
          source_file = BawWorkers::Validation.validate_file(source)
          dest_files = BawWorkers::Validation.validate_files(destinations, false).compact

          [source_file, dest_files]
        end

        # Get a Resque::Status hash for if a mirror job has a matching payload.
        # @param [String] source
        # @param [String, Array<String>] destinations
        # @return [Resque::Plugins::Status::Hash] status
        def get_job_status(source, destinations)
          source_file, destination_files = action_validate(source, destinations)
          payload = {source: source_file, destinations: destination_files}
          BawWorkers::ResqueApi.status(BawWorkers::Mirror::Action, payload)
        end

      end

      # Perform method used by resque-status.
      def perform
        source = options['source']
        destinations = options['destinations']
        self.class.action_perform(source, destinations)
      end

    end
  end
end