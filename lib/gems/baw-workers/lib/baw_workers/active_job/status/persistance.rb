# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    module Status
      # Stores status data in 2 + n places:
      # '_statuses' - is a set of all statuses, useful for bulk operations
      # '_kill' - a set of jobs to kill
      # 'status:{job_id}' - one key/value pair per status
      module Persistance
        PENDING_EXPIRE_IN = 86_400 * 7
        TERMINAL_EXPIRE_IN = 86_400

        module_function

        # @return [::Redis]
        def redis
          raise 'redis is nil, Persistance singleton must be configured before use' if @redis.nil?

          @redis
        end

        #
        # Configure the persistance module. This module is a singleton.
        #
        # @param [::Redis] redis The redis client to use
        #
        # @return [Persistance] the configured Persistance Module
        #
        def configure(redis)
          unless redis.class.ancestors.include?(::Redis)
            raise ArgumentError,
                  "redis was not of type Redis, ancestors: #{redis.class.ancestors}"
          end

          @redis = redis
          self
        end

        def expire_values
          {
            pending: PENDING_EXPIRE_IN,
            completed: TERMINAL_EXPIRE_IN
          }
        end

        # @param status [StatusData]
        # @param delay_ttl [Integer] - seconds, use to up the TTL for scheduled jobs.
        # @return [Boolean] true if created, false is the status already exists
        def create(status, delay_ttl: 0)
          # save the status to status:{job_id}
          success = redis.set(
            *prepare_status(status),
            ex: expire_in(status) + delay_ttl,
            nx: true # set the key unless it already exists
          )
          return false unless success

          # add the job_id to a list of known statuses
          redis.zadd(known_statuses_set, Time.now.to_i, status.job_id)

          # clean up old statuses
          clean_known_statuses

          true
        end

        # @param status [StatusData]
        # @return [Boolean] true if the status was set
        def set(status)
          redis.set(
            *prepare_status(status),
            ex: expire_in(status),
            xx: true # only set the key if it already exists
          )
        end

        #
        # Checks if the given status exists
        #
        # @param [String,StatusData] job_id
        #
        # @return [Boolean]
        #
        def exists?(job_id)
          redis.exists?(status_prefix(check_job_id(job_id)))
        end

        # get a status with a given job_id
        # @param job_id [String]
        # @return [StatusData] the status, or nil if it was not found
        def get(job_id)
          check_job_id(job_id)
          decode(redis.get(status_prefix(job_id)))
        end

        # Get multiple statuses
        # @param *job_ids [Array<String>]
        # @return [Array<StatusData>]
        def get_many(*job_ids)
          return [] if job_ids.empty?

          status_job_ids = job_ids.map(&method(:status_prefix))
          values = redis.mget(*status_job_ids) || []
          values.map(&method(:decode))
        end

        # delete a status
        # @param job_id [String]
        # @return [Boolean]
        def remove(job_id)
          check_job_id(job_id)

          # either the key exists or is expired and deleted by redis
          [
            (redis.del(status_prefix(job_id)) <= 1),
            redis.zrem(known_statuses_set, job_id),
            redis.srem(kill_set, job_id)
          ].any?
        end

        #
        # Get the count of statuses currently known to us
        #
        # @return [Integer] the count of statuses
        #
        def count
          redis.zcard(known_statuses_set)
        end

        # query statuses in reverse chronological order (most recent first) by index.
        # Defaults to getting all statuses.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @param range_end [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @return [Array<String>]
        # @example retuning the last 20 statuses
        #   Persistance.get_status_ids(0, 20)
        def get_status_ids(range_start = nil, range_end = nil)
          # Because we want a reverse chronological order, we need to get a range starting
          # by the highest negative number.
          range_start = range_start&.to_i&.abs || 0
          range_end = range_end&.to_i&.abs || -1
          redis.zrevrange(known_statuses_set, range_start, range_end) || []
        end

        # Return StatusData objects in reverse chronological order by index.
        # By default returns the entire set.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @param range_end [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @return [Array<StatusData>]
        # @example retuning the last 20 statuses
        #   Persistance.statuses(0, 20)
        def get_statuses(range_start = nil, range_end = nil)
          ids = get_status_ids(range_start, range_end)
          return [] if ids.empty?

          get_many(*ids).compact
        end

        # clear statuses from redis passing an optional range.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @param range_end [Integer] - an index into the set, sorted by score, high to low, !inclusive!
        # @param status [String] - if not nil, will only removes statuses of status provided.
        # @return [Integer] - the count of deleted statuses
        def clear(range_start = nil, range_end = nil, status: nil)
          raise ArgumentError, "#{status} is not a valid status" unless status.nil? || STATUSES.include?(status)

          get_status_ids(range_start, range_end).count do |job_id|
            # no status filtering

            next remove(job_id) if status.nil?

            status_data = get(job_id)

            # status removed (by ttl) so clean up known and kill sets
            next remove(job_id) if status_data.nil?

            # or if status matches filter
            next remove(job_id) if status_data.status == status

            next false
          end
        end

        # Removes status job_ids from the known statuses list if their associated status data is no longer in redis.
        # Ideally redis will clean statuses when their TTL expires, this will finish cleaning.
        # It will only check job_ids that are older than the default expire time and will leave job_ids that still have
        # associated status data entries
        # @return [void]
        def clean_known_statuses
          redis.zrangebyscore(known_statuses_set, 0, Time.now.to_i - TERMINAL_EXPIRE_IN).each do |id|
            remove(id)
          end
        end

        # Kill the job at job_id on its next iteration this works by adding the job_id to a
        # kill list (a.k.a. a list of jobs to be killed. Each iteration the job checks
        # if it _should_ be killed by calling <tt>tick</tt> or <tt>at</tt>. If so, it raises
        # a <tt>Killed</tt> error and sets the status to 'killed'.
        # @param job_id [String]
        def mark_for_kill(job_id)
          check_job_id(job_id)
          redis.sadd(kill_set, job_id)
        end

        # Remove the job at UUID from the kill list
        # @param job_id [String]
        def killed(job_id)
          check_job_id(job_id)
          redis.srem(kill_set, job_id)
        end

        # @return [Array<string>]
        def marked_for_kill_ids
          redis.smembers(kill_set)
        end

        def mark_all_for_kill(range_start = nil, range_end = nil)
          get_status_ids(range_start, range_end).collect do |id|
            mark_for_kill(id)
          end
        end

        def mark_for_kill_count
          redis.scard(kill_set)
        end

        # @param job_id [String]
        # @return [Boolean]
        def should_kill?(job_id)
          check_job_id(job_id)
          redis.sismember(kill_set, job_id)
        end

        # @param job_id [String]
        # @return [String]
        def status_prefix(job_id)
          "activejob:status:#{job_id}"
        end

        def known_statuses_set
          'activejob:statuses'
        end

        def kill_set
          'activejob:statuses:kill'
        end

        # @param status [StatusData]
        # @return [Integer] when this key should expire
        def expire_in(status)
          return TERMINAL_EXPIRE_IN if TERMINAL_STATUSES.include?(status.status)

          PENDING_EXPIRE_IN
        end

        # @param status [StatusData]
        # @return [String]
        def encode(status)
          check_status(status)

          status.to_json({ time_precision: 9 })
        end

        # @param status_string [String]
        # @return [StatusData]
        def decode(status_string)
          return nil if status_string.nil?

          raise ArgumentError, 'status_string was not a string' unless status_string.is_a?(String)

          hash = JSON.parse(status_string, { symbolize_names: true })
          StatusData.new(hash)
        rescue StandardError => e
          context = ''
          context += "#{e.message}\nContext: status_string=#{status_string}" if BawApp.dev_or_test?
          raise e.exception(context)
        end

        def check_status(status)
          raise ArgumentError, 'status was not a StatusData' unless status.is_a?(StatusData)
        end

        def check_job_id(job_id)
          raise ArgumentError, 'job_id was not a non-blank string' unless job_id.is_a?(String) && !job_id.blank?
          raise ArgumentError, 'job_id cannot contain a space' if job_id.include?(' ')

          job_id
        end

        def prepare_status(status)
          check_status(status)
          [
            status_prefix(status.job_id),
            encode(status)
          ]
        end

        def inspect
          format('#<%s:0x%x <cut>>', self.class, object_id)
        end

        private :prepare_status, :check_status, :check_job_id
      end
    end
  end
end
