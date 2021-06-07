# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    module Status
      # Stores status data in 2 + n places:
      # '_statuses' - is a set of all statuses, useful for bulk operations
      # '_kill' - a set of jobs to kill
      # 'status:{job_id}' - one key/value pair per status
      class Persistance
        include Singleton

        PENDING_EXPIRE_IN = 86_400 * 7
        COMPLETED_EXPIRE_IN = 86_400

        # @return [Redis]
        def redis
          raise "redis is nil, Persistance singleton must be configured before use" if @redis.nil?
          @redis
        end

        def configure(redis)
          raise ArgumentError, "redis was not of type Redis, ancestors: #{redis.class.ancestors}" unless redis.class.ancestors.include?(Redis)
          @redis = redis
        end

        def expire_values
          {
            pending: PENDING_EXPIRE_IN,
            completed: COMPLETED_EXPIRE_IN
          }
        end


        # @param status [StatusData]
        # @param delay_ttl [Integer] - seconds, use to up the TTL for scheduled jobs.
        # @return [Boolean] true if created, false is the status already existed
        def create(status, delay_ttl: 0)
          return false if exists?(status.job_id)

          # save the status to status:{job_id}
          set(status, delay_ttl: delay_ttl)

          # add the job_id to a list of known statuses
          redis.zadd(known_statuses_set, Time.now.to_i, status.job_id)

          # clean up old statuses
          clean_known_statuses

          true
        end

        # @param status [StatusData]
        # @return [StatusData] the status is returned
        def set(status, delay_ttl: 0)
          check_status(status)
          data = status.to_json
          redis.set(status_prefix(status.job_id), data, ex: expire_in(status) + delay_ttl)
          status
        end

        def exists?(job_id)
          redis.exists?(status_prefix(job_id))
        end

        # get a status with a given job_id
        # @param job_id [String]
        # @return [StatusData]
        def get(job_id)
          decode(redis.get(status_prefix(job_id)))
        end

        # Get multiple statuses
        # @param job_ids [Array<String>]
        # @return [Array<StatusData>]
        def get_many(job_ids)
          return [] if job_ids.empty?

          status_job_ids = job_ids.map(&:status_prefix)
          values = redis.mget(*status_job_ids)
          values.map(decode)
        end

        # delete a status
        # @param job_id [String]
        def remove(job_id)
          redis.del(status_prefix(job_id))
          redis.zrem(known_statuses_set, job_id)
          redis.srem(kill_set, job_id)
        end

        def count
          redis.zcard(known_statuses_set)
        end

        # query statuses in reverse chronological order (most recent first).
        # Defaults to getting all statuses.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low
        # @param range_end [Integer] - an index into the set, sorted by score, high to low
        # @return [Array<String>]
        # @example retuning the last 20 statuses
        #   Persistance.get_job_ids_by_page(0, 20)
        def get_job_ids_by_page(range_start = nil, range_end = nil)
          # Because we want a reverse chronological order, we need to get a range starting
          # by the highest negative number.
          range_start = range_start.nil? ? 0 : range_start.to_i.abs
          range_end = range_end.nil? ? -1 : range_end.to_i.abs
          redis.zrevrange(set_job_id, range_start, range_end) || []
        end

        # Return StatusData objects in reverse chronological order.
        # By default returns the entire set.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low
        # @param range_end [Integer] - an index into the set, sorted by score, high to low
        # @example retuning the last 20 statuses
        #   Persistance.statuses(0, 20)
        def get_many_by_page(range_start = nil, range_end = nil)
          ids = get_job_ids_by_page(range_start, range_end)
          mget(ids).compact || []
        end

        # clear statuses from redis passing an optional range.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low
        # @param range_end [Integer] - an index into the set, sorted by score, high to low
        def clear(range_start = nil, range_end = nil)
          get_job_ids_by_page(range_start, range_end).each do |job_id|
            remove(job_id)
          end
        end

        # clear statuses from redis which have a status, passing an optional range.
        # @param range_start [Integer] - an index into the set, sorted by score, high to low
        # @param range_end [Integer] - an index into the set, sorted by score, high to low
        def clear_statuses(range_start = nil, range_end = nil, status:)
          raise ArgumentError, "#{status} is not a valid status" unless STATUSES.include?(status)

          get_many_by_page(range_start, range_end).each do |data|
            remove(data) if data.status == status
          end
        end

        # Removes status job_ids from the known statuses list if their associated status data is no longer in redis.
        # Ideally redis will clean statuses when their TTL expires, this will finish cleaning.
        # It will only check job_ids that are older than the default expire time and will leave job_ids that still have
        # associated status data entries
        def clean_known_statuses
          old_job_ids = redis.zrangebyscore(known_statuses_set, 0, Time.now.to_i - COMPLETED_EXPIRE_IN)
          old_job_ids.reject(&:exists).each(&:remove)
        end

        # Kill the job at job_id on its next iteration this works by adding the job_id to a
        # kill list (a.k.a. a list of jobs to be killed. Each iteration the job checks
        # if it _should_ be killed by calling <tt>tick</tt> or <tt>at</tt>. If so, it raises
        # a <tt>Killed</tt> error and sets the status to 'killed'.
        # @param job_id [String]
        def kill(job_id)
          redis.sadd(kill_set, job_id)
        end

        # Remove the job at UUID from the kill list
        # @param job_id [String]
        def killed(job_id)
          redis.srem(kill_set, job_id)
        end

        # @return [Array<string>]
        def kill_job_ids
          redis.smembers(kill_set)
        end

        def kill_all(range_start = nil, range_end = nil)
          status_ids(range_start, range_end).collect do |id|
            kill(id)
          end
        end

        # @param job_id [String]
        # @return [Boolean]
        def should_kill?(job_id)
          redis.sismember(kill_set, job_id)
        end

        # @param job_id [String]
        # @return [String]
        def status_prefix(job_id)
          "status:#{job_id}"
        end

        def known_statuses_set
          '_statuses'
        end

        def kill_set
          '_kill'
        end

        # @param status [StatusData]
        # @return [Integer] when this key should expire
        def expire_in(status)
          return COMPLETED_EXPIRE_IN if EXPIRE_STATUSES.include?(status.status)

          PENDING_EXPIRE_IN
        end

        def check_status(status)
          raise ArgumentError, 'status was not a StatusData' unless status.is_a?(StatusData)
        end

        # @param status [StatusData]
        # @return [String]
        def encode(status)
          status.to_json
        end

        # @param status_string [String]
        # @return [StatusData]
        def decode(status_string)
          return nil if status_string.nil?

          StatusData.new(JSON.parse(status_string))
        end
      end
    end
  end
end
