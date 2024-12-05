# frozen_string_literal: true

# Patches for the Object class.
module BawApp
  # Extensions to all objects
  module Object
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

    # Get the memory address of an object.
    # THIS IS A HUGE HACK
    # @return [String] the memory address of the object, formatted as a hex string.
    def object_address
      token = '"address":"'
      # Ruby changes the way object_id works in Ruby 2.7: to allow compaction
      # of memory the object_id is no longer related to the memory address at all.
      # The only API I've found that emits the address like it is in inspect
      # is ObjectSpace.dump... and that returns a bunch of stuff I don't want.
      # Suffice to say this is not great, but it works.
      dump = ObjectSpace.dump(self)
      start = dump.index(token) + token.length
      stop = dump.index('"', start)

      format('0x%016x', (dump[start...stop]).hex)
    end

    def toggle(name)
      raise 'name must be a symbol' unless name.is_a?(Symbol)

      writer_name = :"#{name}="
      raise "#{name} must have a writer" unless respond_to?(writer_name)

      original = send(name)
      begin
        send(writer_name, !original)
        yield
      ensure
        send(writer_name, original)
      end
    end

    # Yield self if condition is true.
    # Used for conditional chaining.
    # @param condition [Boolean] the condition to check
    # @yield [Object] self
    # @return [Object] self if false, the result of the block if true
    def yield_if(condition)
      return self unless condition

      yield self
    end

    alias if_then yield_if
  end
end

Object.prepend BawApp::Object
