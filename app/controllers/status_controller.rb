# frozen_string_literal: true

# Controller for the status endpoint
class StatusController < ApplicationController
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
      upload&.success?, upload&.fmap { |audio_recording|
                          audio_recording.try(:data_provider).fetch(:error) == ''
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
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.connection.verify!
        end
      },
      Concurrent::Promises::FactoryMethods.future {
        BawWorkers::Config.batch_analysis.remote_connected?
      }.timeout(2, false)
    )
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
