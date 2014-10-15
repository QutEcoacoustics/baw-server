module BawWorkers
  # Custom api for access to resque information.
  class ResqueApi
    class << self

      # Is this type of job with these args currently queued?
      # @param [Class] klass
      # @param [Hash] args
      # @return [Boolean]
      def job_queued?(klass, *args)
        # from https://github.com/neighborland/resque_solo/blob/master/lib/resque_ext/resque.rb
        job_queued_in?(Resque.queue_from_class(klass), klass, *args)
      end

      # Does this queue have this type of job with these args?
      # @param [String] queue
      # @param [Class] klass
      # @param [Hash] args
      # @return [Boolean]
      def job_queued_in?(queue, klass, *args)
        # from https://github.com/neighborland/resque_solo/blob/master/lib/resque_ext/resque.rb
        item = {class: klass.to_s, args: args}
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
        jobs
      end

      # Get jobs in this queue.
      # @param [String] queue
      # @return [Array<Hash>]
      def jobs_queued_in(queue)
        # from http://blog.mojotech.com/hello-resque-whats-happening-under-the-hood/
        payloads = []
        index = 0
        while payload = Resque.redis.lindex("queue:#{queue}", index) do
          payloads << Resque.decode(payload).merge(queue: queue)
          index += 1
        end
        payloads
      end

      # Get jobs in this queue of this type.
      # @param [String] queue
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_queued_in_of(queue, klass)
        jobs_queued_in(queue).select { |job| job['class'] == klass.to_s }
      end

      # Get jobs in this queue of this type with these args.
      # @param [String] queue
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_queued_in_of_with(queue, klass, *args)
        jobs_queued_in(queue).select { |job| job['class'] == klass.to_s && Resque.encode(args) == job['args'] }
      end

      # Get queued jobs of this type.
      # @param [Class] klass
      # @return [Array<Hash>]
      def jobs_queued_of(klass)
        jobs_queued.select { |job| job['class'] == klass.to_s }
      end

      # Get queued jobs of this type with these args.
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_queued_of_with(klass, *args)
        jobs_queued.select { |job| job['class'] == klass.to_s && Resque.encode(args) == job['args'] }
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
        jobs_running.select { |job| job['class'] == klass.to_s }
      end

      # Get the currently running jobs.
      # @param [Class] klass
      # @param [Hash] args
      # @return [Array<Hash>]
      def jobs_running_of_with(klass, *args)
        jobs_running.select { |job| job['class'] == klass.to_s && Resque.encode(args) == job['args'] }
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
      def jobs_of_with(klass, *args)
        jobs_queued_of_with(klass, args) + jobs_running_of_with(klass, args)
      end

    end
  end
end