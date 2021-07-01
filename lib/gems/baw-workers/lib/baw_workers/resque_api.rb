# frozen_string_literal: true

module BawWorkers
  # Custom api for access to resque information.
  module ResqueApi
    module_function

    # Get a count of jobs that are pending in all queues.
    # @return [Integer]
    def queued_count
      Resque.queue_sizes.inject(0) { |sum, (_queue_name, queue_size)| sum + queue_size }
    end

    # Get a count of jobs that are in the resque scheduler delay queue.
    # @return [Integer]
    def delayed_count
      Resque.delayed_queue_schedule_size
    end

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
    def job_queued_in?(_queue, _klass, _args = {})
      raise 'deprecated'
      # from https://github.com/neighborland/resque_solo/blob/master/lib/resque_ext/resque.rb
      # item = BawWorkers::ResqueJobIdBROKEN!!!.create_payload(klass, args)
      # return nil unless ResqueSolo::Queue.is_unique?(item)

      # ResqueSolo::Queue.queued?(queue, item)
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
      while (payload = Resque.redis.lindex("queue:#{queue}", index))
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
      check_class(klass)
      match_klass = klass.to_s
      jobs_queued_in(queue).select { |job| job_class(job) == match_klass }
    end

    # Get jobs in this queue of this type with these args.
    # @param [String] queue
    # @param [Class] klass
    # @param [Hash] args
    # @return [Array<Hash>]
    def jobs_queued_in_of_with(_queue, _klass, _args = {})
      raise 'deprecated'
      # item = BawWorkers::ResqueJobIdBROKEN!!!.create_payload(klass, args)
      # jobs_queued_in(queue).select { |job| job_class(job) == item['class'] && compare_args(job['args'], item['args']) }
    end

    # Get queued jobs of this type.
    # @param [Class] klass
    # @return [Array<Hash>]
    def jobs_queued_of(klass)
      check_class(klass)
      match_klass = klass.to_s
      puts jobs_queued
      jobs_queued.select { |job| job_class(job) == match_klass }
    end

    # Get queued jobs of this type with these args.
    # @param [Class] klass
    # @param [Hash] args
    # @return [Array<Hash>]
    def jobs_queued_of_with(_klass, _args = {})
      raise 'deprecated'
      # item = BawWorkers::ResqueJobIdBROKEN!!!.create_payload(klass, args)
      # jobs_queued.select { |job| job['class'] == item['class'] && compare_args(job['args'], item['args']) }
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
      jobs_running.select { |job| job_class(job) == match_klass }
    end

    # Get the currently running jobs.
    # @param [Class] klass
    # @param [Hash] args
    # @return [Array<Hash>]
    def jobs_running_of_with(_klass, _args = {})
      raise 'deprecated'
      # item = BawWorkers::ResqueJobIdBROKEN!!!.create_payload(klass, args)
      # jobs_running.select { |job| job['class'] == item['class'] && compare_args(job['args'], item['args']) }
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

      BawWorkers::Validation.compare(a_array, b[1..])
    end

    # clear worker heartbeats from redis
    def clear_workers
      workers = Resque.workers

      workers.each(&:unregister_worker)
    end

    # List all running workers.
    # @return [Array] details of running workers
    def workers_running
      workers = Resque.workers
      running_workers = []

      if workers.empty?
        BawWorkers::Config.logger_worker.info {
          'No Resque workers currently running.'
        }
      else

        BawWorkers::Config.logger_worker.info do
          "There are #{workers.size} Resque workers currently running."
        end

        workers.each do |worker|
          running_workers.push(worker.to_s)
        end

        BawWorkers::Config.logger_worker.info {
          worker_details = running_workers.map { |worker|
            host, pid, queues = worker.split(':')
            { host: host, pid: pid, queues: queues }
          }.join(',')

          "Resque worker details: #{worker_details}."
        }

      end

      running_workers
    end

    # Quit all running workers.
    # Only works on the current host!
    # @return [Array<Integer>] worker pids
    def workers_stop_all
      pids = []
      Resque.workers.each do |worker|
        pids.concat(worker.worker_pids)
      end

      pids = pids.uniq

      BawWorkers::Config.logger_worker.info do
        "Pids of running Resque workers: '#{pids.join(',')}'."
      end

      unless pids.empty?
        syscmd = "kill -s QUIT #{pids.join(' ')}"

        BawWorkers::Config.logger_worker.warn do
          "Running syscmd to kill all workers: '#{syscmd}'"
        end

        system(syscmd)
      end

      pids
    end

    def clear_queues(env = BawApp.env)
      env_regex = Regexp.new(env)
      Resque
        .queues
        .select { |queue| queue =~ env_regex }
        .each { |queue| clear_queue(queue) }
    end

    # Clear a queue
    # @see https://gist.github.com/denmarkin/1228863
    # @param [String] queue
    # @return [void]
    def clear_queue(queue)
      BawWorkers::Config.logger_worker.warn do
        "Clearing queue #{queue}..."
      end
      Resque.remove_queue(queue)
      BawWorkers::ActiveJob::Status::Persistance.clear
    end

    # Clear resque stats
    # @see https://gist.github.com/denmarkin/1228863
    # @return [void]
    def clear_stats
      BawWorkers::Config.logger_worker.warn do
        'Clearing stats...'
      end
      Resque.redis.set 'stat:failed', 0
      Resque.redis.set 'stat:processed', 0
    end

    # Get the count of failed jobs.
    # @return [Integer] The number of failed jobs.
    def failed_count
      Resque::Failure.count
    end

    # Get all failed jobs
    # @param [Class] klass the type to filter on. If nil, returns jobs of any class type.
    # @return [Array<Resque::Failure>] an array of failed jobs.
    def failed(klass: nil)
      failed = Resque::Failure.all(0, failed_count, nil)
      failed = failed.filter { |f| f.dig('payload', 'class') == klass.to_s } unless klass.nil?

      failed
    end

    # Retry failed jobs
    # @see https://gist.github.com/CharlesP/1818418754aec03403b3
    def retry_failed
      redis = Resque.redis
      failure_count = Resque::Failure.count
      retried_count = 0

      BawWorkers::Config.logger_worker.warn do
        "Retrying failed jobs (total : #{failure_count})."
      end

      (0...failure_count).each do |i|
        serialized_job = redis.lindex(:failed, i)
        job = Resque.decode(serialized_job)

        next if job.nil?

        next unless job['exception'] == 'Resque::DirtyExit'

        retried_count += 1
        BawWorkers::Config.logger_worker.warn do
          "Retrying job  #{job_class(job)}..."
        end
        Resque::Failure.requeue(i)
        Resque::Failure.remove(i)
      end

      BawWorkers::Config.logger_worker.warn {
        "Retried #{retried_count} failed jobs."
      }
    end

    # Get a Resque::Status hash for the matching action job and payload.
    # Required when you need to regenerate a deterministic key.
    # @param [Class] action_class
    # @param [Hash] args
    # @return [BawWorkers::ActiveJob::Status::StatusData] status
    def status(_action_class, _args = {})
      raise 'deprecated'
      # job_id = BawWorkers::ResqueJobIdBROKEN!!!.create_id_props(action_class, args)
      # BawWorkers::ActiveJob::Status::Persistance.get(job_id)
    end

    # Get a Resque::Status hash for the provided unique key.
    # @param [String] unique_key - the key that uniquely identifies this action. Typically a uuid.
    # @return [BawWorkers::ActiveJob::Status::StatusData] status
    def status_by_key(unique_key)
      BawWorkers::ActiveJob::Status::Persistance.get(unique_key)
    end

    # Get a resque:status' key expire time
    # @return [Integer] the TTL of the key
    def status_ttl(unique_key)
      key = BawWorkers::ActiveJob::Status::Persistance.status_key(unique_key)
      BawWorkers::ActiveJob::Status::Persistance.redis.ttl(key)
    end

    # Get a list of statuses.
    # Most useful for getting completed jobs.
    # @param [Array<String>] statuses which statuses to retrieve
    # @param [Class] klass the type to filter on
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>] an array of job statuses.
    def statuses(statuses: nil, klass: nil)
      results = BawWorkers::ActiveJob::Status::Persistance.get_statuses
      results = results.filter { |s| statuses.include?(s.status) } unless statuses.blank?

      unless klass.nil?
        class_name = klass.to_s
        results = results.filter { |s| class_name = s.klass }
      end

      results
    end

    def statuses_count
      BawWorkers::ActiveJob::Status::Persistance.count
    end

    def check_class(klass)
      raise ArgumentError, 'klass should be a class' unless klass.is_a?(Class)

      return if klass.ancestors.include?(::ActiveJob::Base)

      raise "All jobs should inherit from ActiveJob, #{klass.name} does not"
    end

    def job_class(job_hash)
      job_hash.dig('args', 0, 'job_class')
    end
  end
end
