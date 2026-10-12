# frozen_string_literal: true

# Controller for the status endpoint
class StatusController < ApplicationController
  BATCH_ANALYSIS_TIMEOUT_SECONDS = 2
  # Keep stalled checks from slowing down the test suite for a full minute.
  BATCH_ANALYSIS_CACHE_TTL_SECONDS = Rails.env.test? ? 10 : 60
  BATCH_ANALYSIS_POLL_INTERVAL_SECONDS = 0.1

  skip_authorization_check only: [:index]

  # GET /status
  # GET /status.json (for backwards compatibility)
  # only returns json
  def index
    statuses = start_checks

    timed_out = statuses.wait(10) == false

    storage, redis, upload, database, batch_analysis = statuses.value(0)

    # check promise values contain healthy values for each check.
    # is any promise was rejected then #value returns nil
    status = [
      !timed_out,
      statuses.fulfilled?,
      storage&.fetch(:success, false),
      redis == 'PONG',
      upload&.success?, upload&.fmap { |payload|
                          payload.try(:data_provider).fetch(:error) == ''
                        }&.value_or(false),
      database,
      batch_analysis
    ].all?

    result = {
      status: status ? 'good' : 'bad',
      timed_out:,
      database: safe_result(statuses, index: 3),
      redis: safe_result(statuses, index: 1),
      storage: safe_result(statuses, index: 0) { |v| v[:message] },
      upload: safe_result(statuses, index: 2) { |v|
        status = v.value_or(v.failure&.response&.fetch(:body))
        case status
        when SftpgoClient::ApiResponse
          [status.message, status.error].compact.join('. ')
        when SftpgoClient::ServicesStatus
          error = status.data_provider[:error]
          error.presence || 'Alive'
        else
          status.to_s.strip
        end
      },
      batch_analysis: safe_result(statuses, index: 4) { |v|
        v ? 'Connected' : 'Failed to connect'
      }
    }

    render json: result, status: :ok
  end

  private

  def start_checks
    # https://github.com/QutEcoacoustics/baw-server/issues/795
    # https://guides.rubyonrails.org/v7.1/threading_and_code_execution.html#permit-concurrent-loads
    # Another way to achieve safety here is to create and then shut down a
    # dedicated thread pool each request. I suspect though that that is inefficient.
    # Another idea I tried is https://github.com/luizkowalski/concurrent_rails/tree/main
    # But the API varied too much from concurrent-ruby and it was confusing.
    # In the end I've gone with a very minimal executor.wrap but take care:
    # That only stops connection leaks for that promise it is in. Ideally every
    # callback in every promise should be wrapped in executor.wrap.
    Concurrent::Promises::FactoryMethods.zip(
      Concurrent::Promises::FactoryMethods.future {
        # indicates if audio recording storage is available
        AudioRecording.check_storage
      },
      Concurrent::Promises::FactoryMethods.future {
        # can we ping redis?
        BawWorkers::Config.redis_communicator.ping
      },
      Concurrent::Promises::FactoryMethods.future {
        # can we ping upload service?
        BawWorkers::Config.upload_communicator.service_status
      },
      Concurrent::Promises::FactoryMethods.future {
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection.verify!
        end
      },
      Concurrent::Promises.any(
        Concurrent::Promises.schedule(BATCH_ANALYSIS_TIMEOUT_SECONDS).then { raise 'timeout' },
        Concurrent::Promises::FactoryMethods.future {
          batch_analysis_connected?
        }
      )
    )
  end

  def batch_analysis_connected?
    communicator = BawWorkers::Config.redis_communicator
    key = 'status:batch_analysis:connected'
    value = communicator.get(key)
    if value.is_a?(String) && value.start_with?('pending')
      value = wait_for_batch_analysis_result(communicator, key, value)
    end
    # A cached false is a valid result, not a cache miss.
    return value unless value.nil?

    # Identify this check so a late result cannot overwrite a newer check after the key expires.
    pending = communicator.encode("pending:#{SecureRandom.uuid}")
    # NX elects one checker atomically; the TTL allows recovery if that checker hangs.
    claimed = communicator.redis.set(
      communicator.add_namespace(key), pending, ex: BATCH_ANALYSIS_CACHE_TTL_SECONDS, nx: true
    )
    # Another request claimed the cache between our read and SET; read its value instead.
    return batch_analysis_connected? unless claimed

    value = BawWorkers::Config.batch_analysis.remote_connected?
    cache_batch_analysis_result(communicator, key, pending, value)
    value
  end

  def wait_for_batch_analysis_result(communicator, key, value)
    # Use the same time budget as the promise timeout, unaffected by wall-clock changes.
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + BATCH_ANALYSIS_TIMEOUT_SECONDS
    # Poll while another request owns the check; do not open another remote connection.
    # The deadline bounds this worker's wait because the promise timeout does not stop it.
    while value.is_a?(String) && value.start_with?('pending')
      raise 'timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep BATCH_ANALYSIS_POLL_INTERVAL_SECONDS
      value = communicator.get(key)
    end

    value
  end

  def cache_batch_analysis_result(communicator, key, pending, value)
    # Compare ownership and write atomically: separate GET/SET calls could overwrite
    # a newer pending marker or result if this check outlived its cache lease.
    script = <<~LUA
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('SET', KEYS[1], ARGV[2], 'EX', ARGV[3])
      end
    LUA
    communicator.redis.eval(script, keys: [communicator.add_namespace(key)],
      argv: [pending, communicator.encode(value), BATCH_ANALYSIS_CACHE_TTL_SECONDS])
  end

  # Transform a promise into a safe string
  # @param [Concurrent::Promises::Future] promise
  def safe_result(promise, index:)
    return 'unknown' if promise.pending?

    # result returns a tuple (an array) of
    # [fulfilled?, value, reason]
    # In our case, the value and reasons are arrays of values because we're
    # dealing with a series of zipped promises
    fulfilled, values, reasons = promise.result(0)
    return 'timed out' if fulfilled.nil?

    value = values[index]
    return "error: #{reasons[index]}" if value.nil?

    begin
      (block_given? ? yield(value) : value)
    rescue StandardError => e
      Rails.logger.error(e)
      'error getting value'
    end
  end
end
