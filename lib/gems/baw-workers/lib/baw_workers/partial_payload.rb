# frozen_string_literal: true

module BawWorkers
  class PartialPayloadMissingError < StandardError
  end

  class InconsistentBasePayloadError < StandardError
  end

  # Stores Redis string payloads in multiple parts.
  # Useful for splitting apart large payloads that are stuck in, for example, Redis LISTs.
  # In the common scenario of using a LIST to store job payloads for a processing system, the large invariant parts
  # of payloads can be split apart and stored separately. We experience 92-96% less memory usage using this technique
  # on very large payloads for large job sets (e.g. 1000 or more).
  # This technique should be used when you have at least 100 payloads which are largely identical.
  class PartialPayload
    @communicator = BawWorkers::Config.redis_communicator

    class << self
      # The name of the field to embed in the variant payload. `payload_base` should suggest to the uninitiated
      # that there is a base payload somewhere else that needs to be resolved.
      PARTIAL_PAYLOAD_KEY = 'payload_base'

      REDIS_NAMESPACE = 'partial_payload'

      BASE_PAYLOAD_EXPIRE = 86_400 * 365 # 1 year

      # Store a base payload that should be merged with a partial payload.
      # See the tests for clear examples.
      # @param [Hash] base_payload - they base payload to store
      # @param [Object] key - a unique key used to retrieve the payload
      # @return [Hash] a partial payload hashed. This hash should be merged with your actual payload.
      def create(base_payload, key)
        key = add_namespace(key)

        # set a very long expire. We don't care if these payloads exist for a very long time.
        out_opts = {
          expire_seconds: BASE_PAYLOAD_EXPIRE
        }
        success = @communicator.set(key, base_payload, out_opts)

        raise 'PartialPayload creation failed' unless success

        # return a hash with the absolute redis_key that can be used to retrieve the base payload
        { PARTIAL_PAYLOAD_KEY.to_sym => out_opts[:key] }
      end

      # Store a base payload that should be merged with a partial payload, OR if it already exists, validates that the
      # two payloads are identical.
      # @param [Hash] base_payload - the base payload to store
      # @param [Object] key - a unique key used to retrieve the payload
      # @return [Hash] a partial payload hashed. This hash should be merged with your actual payload.
      def create_or_validate(base_payload, key)
        existing_base = get(key)
        if existing_base
          normalized_base = BawWorkers::ResqueJobIdBROKEN!!!.normalise(base_payload)
          if existing_base != normalized_base
            message = "Existing base `#{existing_base}` did not match #{normalized_base}"
            raise InconsistentBasePayloadError, message
          end

          # return a hash with the absolute redis_key that can be used to retrieve the base payload
          { PARTIAL_PAYLOAD_KEY.to_sym => @communicator.add_namespace(add_namespace(key)) }
        else
          create(base_payload, key)
        end
      end

      # Reconstruct a payload by combining a partial payload with its base payload.
      # resolve can reconstruct several nested payload partials via recursion. Its only limitations
      # are callstack size and Redis performance.
      # Payloads that are not hashes or are hashes without the partial payload key, are ignored and returned unmodified.
      # @param [Hash] payload
      # @return [Hash] the reconstructed payload
      def resolve(payload)
        return payload unless payload.is_a?(Hash)

        has_string = payload.key?(PARTIAL_PAYLOAD_KEY)
        has_symbol = payload.key?(PARTIAL_PAYLOAD_KEY.to_sym)
        if has_string || has_symbol
          # we assume the full redis key (with namespaces) has been stored
          redis_key = payload.delete(has_string ? PARTIAL_PAYLOAD_KEY : PARTIAL_PAYLOAD_KEY.to_sym)

          base = @communicator.get(redis_key, no_namespace: true)

          raise PartialPayloadMissingError, "Could not retrieve partial payload `#{redis_key}`" if base.nil?

          # RECURSIVE - allow the base payload to have its own base payload
          new_base = resolve(base)

          payload = new_base.merge(payload)
        end

        payload
      end

      # Gets a base payload if it exists
      # @param [String] key - they key for the base payload to retrieve
      # @return [Hash] returns a Hash if found, otherwise nil
      def get(key)
        key = add_namespace(key)
        @communicator.get(key)
      end

      # Delete the base payload.
      # Does not cascade and delete other linked base payloads.
      # @param [String] key - they key to delete
      # @return [Boolean] True if the delete succeeded.
      def delete(key)
        key = add_namespace(key)

        @communicator.delete(key)
      end

      # Delete the base payload.
      # *Does* cascade and delete other linked base payloads.
      # Throws `PartialPayloadMissingError` if a linked base payload can not be found.
      # @param [String] key - they key to delete
      # @return [Boolean] True if the delete succeeded.
      def delete_recursive(key)
        has_namespace = key.include?(':' + REDIS_NAMESPACE + ':')
        key = add_namespace(key) unless has_namespace

        # first get the partial payload
        partial = @communicator.get(key, no_namespace: has_namespace)

        if partial.nil?
          # So the stash is in an inconsistent state? what is there to do? little. At least throwing an exception means
          # we will know about it.
          raise PartialPayloadMissingError, "Could not retrieve partial payload `#{key}` during recursive delete"
        end

        # now recurse through linked list
        has_key = has_base_payload(partial)
        if has_key
          # RECURSIVE - allow the base payload to have its own base payload
          delete_recursive(partial[has_key])
        end

        # finally delete
        @communicator.delete(key, no_namespace: has_namespace)
      end

      # Deletes all partial workload keys
      def delete_all
        key = add_namespace('')

        @communicator.delete_all(key)
      end

      private

      def has_base_payload(hash)
        return PARTIAL_PAYLOAD_KEY if hash.key?(PARTIAL_PAYLOAD_KEY)
        return PARTIAL_PAYLOAD_KEY.to_sym if hash.key?(PARTIAL_PAYLOAD_KEY.to_sym)

        nil
      end

      def add_namespace(key)
        REDIS_NAMESPACE + ':' + key
      end
    end
  end
end
