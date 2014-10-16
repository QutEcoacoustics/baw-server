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
        jobs_queued_in(queue).select { |job| job['class'] == item['class'] && compare_args(job['args'],item['args']) }
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
        jobs_queued.select { |job| job['class'] == item['class'] && compare_args(job['args'],item['args']) }
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
        jobs_running.select { |job| job['class'] == item['class'] && compare_args(job['args'],item['args']) }
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
        return false unless a[0].is_a?(String) && b[0].is_a?(String) && a[0] == b[0]

        # if a[1] or b[1] are a hash, convert to array
        mod_a = a[1].is_a?(Array) ? a[1] : a[1].to_a[0]
        mod_b = b[1].is_a?(Array) ? b[1] : b[1].to_a[0]

        # sort the arrays by the first item of the sub-array
        mod_a = mod_a.sort{ |a1, b1| a1[0] <=> b1[0]}
        mod_b = mod_b.sort{ |a1, b1| a1[0] <=> b1[0]}

        mod_a == mod_b
      end

    end
  end
end