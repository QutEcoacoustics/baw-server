# frozen_string_literal: true

# Patches for the Object class.
module ObjectPatch
  # Retry a block of code with exponential backoff.
  # With the default parameters, this will retry 3 times, with a delay of 0, 1, and 4 seconds.
  # @yield [Integer] the current attempt number
  # @param attempts [Integer] the number of attempts to make, defaults to 3
  # @param delay [Integer] the delay between attempts, defaults to 1
  def retry_with_backoff(attempts: 3, delay: 1, logger: nil, on: StandardError)
    attempt = 0

    begin
      attempt += 1

      logger&.info("[retry_with_backoff] Attempt #{attempt} of #{attempts}")
      yield(attempt)
    rescue on
      raise if attempt >= attempts

      sleep_amount = delay * (4**(attempt - 1))
      logger&.warn("[retry_with_backoff] Encountered failure, sleeping for #{sleep_amount} seconds", message: $ERROR_INFO&.message)

      sleep sleep_amount
      retry
    end
  end
end

Object.prepend ObjectPatch
