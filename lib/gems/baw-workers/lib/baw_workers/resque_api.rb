# frozen_string_literal: true

module BawWorkers
  # Custom api for access to resque information.
  module ResqueApi
    include SemanticLogger::Loggable

    module_function

    # Get a count of jobs that are pending in all queues.
    # @return [Integer]
    def queued_count
      Resque.queue_sizes.inject(0) { |sum, (_queue_name, queue_size)| sum + queue_size }
    end

    # Get a count of jobs that are in the resque scheduler delay queue.
    # @return [Integer]
    def delayed_count
      Resque.count_all_scheduled_jobs
    end

    # Deschedule all jobs from the resque scheduler delay queue and run them now.
    def enqueue_delayed_jobs
      Resque.enqueue_delayed_selection { |_job| true }
    end

    # Sets resque-scheduler schedules for all recurring jobs (that use our
    # BawWorkers::ActiveJob::Recurring module).
    # Run this when the scheduler starts.
    def create_all_schedules
      raise 'Dynamic schedules must be in use' unless Resque::Scheduler.dynamic

      # require all jobs
      (BawApp.root / 'lib/gems/baw-workers/lib/baw_workers/jobs').glob('**/*job*.rb').each do |file|
        require_dependency file
      end
      # filter for those that have configured themselves to use a  recurring schedule
      BawWorkers::Jobs::ApplicationJob
        .descendants
        .filter(&:recurring_cron_schedule)
        .each do |job_class|
          BawWorkers::Config.logger_worker.info(
            'rake_task:baw:worker:run_scheduler adding recurring job',
            job_class: job_class.name,
            schedule: job_class.recurring_cron_schedule,
            args: job_class.recurring_cron_schedule_args
          )

          # add the job to the resque scheduler
          Resque.set_schedule(
            job_class.name,
            {
              class: job_class.name,
              cron: job_class.recurring_cron_schedule,
              queue: job_class.queue_name,
              args: job_class.recurring_cron_schedule_args
              # We don't persist the schedule because we set it every time
              # we start up the scheduler (this very process).
              #persist:
            }
          )
        end
    end

    # Remove all resque-scheduler schedules for recurring jobs.
    def clear_all_schedules
      Resque.all_schedules.each do |key, _schedule|
        Resque.remove_schedule(key)
      end
    end

    # Get all currently queued jobs.
    # @return [Array<Hash>]
    def jobs_queued
      jobs = Resque.queues.map { |queue|
        jobs_queued_in(queue)
      }
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

    # Get queued jobs of this type.
    # @param [Class] klass
    # @return [Array<Hash>]
    def jobs_queued_of(klass)
      check_class(klass)
      match_klass = klass.to_s

      jobs_queued.select { |job| job_class(job) == match_klass }
    end

    def peek(queue_name)
      payload = Resque.peek(queue_name)

      deserialize(payload)
    end

    def pop(queue_name)
      # bypass our test pause dequeue module
      payload = Resque.respond_to?(:__pop) ? Resque.__pop(queue_name) : Resque.pop(queue_name)
      Rails.logger.info(payload:)
      deserialize(payload)
    end

    def deserialize(resque_payload)
      return nil if resque_payload.nil?

      ::ActiveJob::Base.deserialize(resque_payload['args'][0]).tap do |job|
        job.send(:deserialize_arguments_if_needed)
      end
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
            { host:, pid:, queues: }
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

    def any_worker_working_on_queue(name)
      logger.measure_debug('ResqueApi::any_worker_working_on_queue') do
        Resque.redis.sscan(:workers, '', { match: "*#{name}*", count: 1 })[1].any?
      end
    end

    def queues_being_worked_on
      logger.measure_debug('ResqueApi::queues_being_worked_on') do
        #Resque::Worker.data_store.worker_ids.map { |id| id&.split(',')&.last }.uniq.compact
        Resque.redis.sscan_each(':workers').map { |id| id }
      end
    end

    def queue_names(env = BawApp.env)
      env_regex = Regexp.new(env)
      Resque.queues.grep(env_regex)
    end

    def clear_queues(env = BawApp.env)
      queue_names(env).each { |queue| clear_queue(queue) }
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
    # @param [Class] of_class the type to filter on
    # @return [Array<BawWorkers::ActiveJob::Status::StatusData>] an array of job statuses.
    def statuses(statuses: nil, klass: nil, of_class: nil)
      of_class ||= klass

      statuses = Array(statuses)
      results = BawWorkers::ActiveJob::Status::Persistance.get_statuses
      results = results.filter { |script| statuses.include?(script.status) } if statuses.present?

      unless of_class.nil?
        check_class(of_class)
        class_name = of_class.to_s
        results = results.filter { |script| class_name == script.options[:job_class] }
      end

      results
    end

    def job_count_by_class
      jobs.group_by { |job| job_class(job) }.transform_values(&:count)
    end

    def statuses_count
      BawWorkers::ActiveJob::Status::Persistance.count
    end

    def statuses_clear
      BawWorkers::ActiveJob::Status::Persistance.clear
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
