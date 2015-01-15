module BawWorkers
  # Custom api for access to resque information.
  class ResqueApi
    class << self

      # Is this type of job with these args currently queued?
      # @param [Class] klass
      # @param [Hash] args
      # @return [Boolean]
      def job_queued?(klass, args = {})
        job_queued_in?(Resque.queue_from_class(klass), klass, args)
      end

      # Does this queue have this type of job with these args?
      # @param [String] queue
      # @param [Class] klass
      # @param [Hash] args
      # @return [Boolean]
      def job_queued_in?(queue, klass, args = {})
        # from https://github.com/neighborland/resque_solo/blob/master/lib/resque_ext/resque.rb
        item = BawWorkers::ResqueJobId.create_payload(klass, args)
        return nil unless ResqueSolo::Queue.is_unique?(item)
        ResqueSolo::Queue.queued?(queue, item)
      end

      # Get all currently queued jobs.
      # @return [Array<Hash>]
      def jobs_queued
        jobs = []
        Resque.queues.each do |queue|
          jobs.push(jobs_queued_in(queue))
        end
        jobs.flatten
      end

      # Get jobs in this queue.
      # @param [String] queue
      # @return [Array<Hash>]
      def jobs_queued_in(queue)
        # from http://blog.mojotech.com/hello-resque-whats-happening-under-the-hood/
        payloads = []
        index = 0
        while payload = Resque.redis.lindex("queue:#{queue}", index) do
          payloads << Resque.decode(payload).merge('queue' => queue)
          index += 1
        end
        payloads
      end

      # Get jobs in this queue of this type.
      # @param [String] queue
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_queued_in_of(queue, klass)
        match_klass = klass.to_s
        jobs_queued_in(queue).select { |job| job['class'] == match_klass }
      end

      # Get jobs in this queue of this type with these args.
      # @param [String] queue
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_queued_in_of_with(queue, klass, args = {})
        item = BawWorkers::ResqueJobId.create_payload(klass, args)
        jobs_queued_in(queue).select { |job| job['class'] == item['class'] && compare_args(job['args'], item['args']) }
      end

      # Get queued jobs of this type.
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_queued_of(klass)
        match_klass = klass.to_s
        jobs_queued.select { |job| job['class'] == match_klass }
      end

      # Get queued jobs of this type with these args.
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_queued_of_with(klass, args = {})
        item = BawWorkers::ResqueJobId.create_payload(klass, args)
        jobs_queued.select { |job| job['class'] == item['class'] && compare_args(job['args'], item['args']) }
      end

      # Get the currently running jobs.
      # @return [Array<Hash>]
      def jobs_running
        # from http://blog.mojotech.com/hello-resque-whats-happening-under-the-hood/
        # payload_class, args, queue
        Resque::Worker.working.map(&:job)
      end

      # Get the currently running jobs.
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_running_of(klass)
        match_klass = klass.to_s
        jobs_running.select { |job| job['class'] == match_klass }
      end

      # Get the currently running jobs.
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_running_of_with(klass, args = {})
        item = BawWorkers::ResqueJobId.create_payload(klass, args)
        jobs_running.select { |job| job['class'] == item['class'] && compare_args(job['args'], item['args']) }
      end

      # Get all jobs.
      # @return [Array<Hash>]
      def jobs
        jobs_queued + jobs_running
      end

      # Get all jobs of this type.
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_of(klass)
        jobs_queued_of(klass) + jobs_running_of(klass)
      end

      # Get all jobs of this type with these args.
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_of_with(klass, args = {})
        jobs_queued_of_with(klass, args) + jobs_running_of_with(klass, args)
      end

      def compare_args(a, b)
        # test payload hash first - must match to continue
        return false unless a[0].is_a?(String) && b[0].is_a?(String) && a[0] == b[0]

        # convert array a to the same format as array b
        a_array = []
        a[1].each_pair do |key, value|
          a_array.push([key, value])
        end

        BawWorkers::Validation.compare(a_array, b[1..-1])
      end

      # List all running workers.
      # @return [Array] details of running workers
      def workers_running
        workers = Resque.workers
        running_workers = []

        if workers.size > 0

          BawWorkers::Config.logger_worker.info(self.name) {
            "There are #{workers.size} Resque workers currently running."
          }

          workers.each do |worker|
            running_workers.push(worker.to_s)
          end

          BawWorkers::Config.logger_worker.info(self.name) {
            worker_details = running_workers.map { |worker|
              host, pid, queues = worker.split(':')
              {host: host, pid: pid, queues: queues}
            }.join(',')

            "Resque worker details: #{worker_details}."
          }

        else
          BawWorkers::Config.logger_worker.info(self.name) {
            'No Resque workers currently running.'
          }
        end

        running_workers
      end

      # Quit all running workers.
      # @return [Array<Integer>] worker pids
      def workers_stop_all
        pids = []
        Resque.workers.each do |worker|
          pids.concat(worker.worker_pids)
        end

        pids = pids.uniq

        BawWorkers::Config.logger_worker.info(self.name) {
          "Pids of running Resque workers: '#{pids.join(',')}'."
        }

        unless pids.empty?
          syscmd = "kill -s QUIT #{pids.join(' ')}"

          BawWorkers::Config.logger_worker.warn(self.name) {
            "Running syscmd to kill all workers: '#{syscmd}'"
          }

          system(syscmd)
        end

        pids
      end

      # Get a Resque::Status hash for the matching action job and payload.
      # @param [Class] action_class
      # @param [Hash] args
      # @return [Resque::Plugins::Status::Hash] status
      def status(action_class, args = {})
        job_id = BawWorkers::ResqueJobId.create_id_props(action_class, args)
        Resque::Plugins::Status::Hash.get(job_id)
      end

    end
  end
end