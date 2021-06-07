# frozen_string_literal: true

require 'securerandom'
# not actually needed, but useful to explicit about a rarely used dependency
require 'deep_sort'

module BawWorkers
  module ActiveJob
    module Identity
      # reference methods for generating job ids
      module Helpers
        # Helper method for generating a random job_id
        # Ensures that every job is unique.
        # @param job [ActiveJob::Base] (unused)
        # @return [String]
        def self.generate_uuid(job)
          key = SecureRandom.uuid
          class_name = job.class.name
          "#{class_name}:#{key}"
        end

        # Helper method for generating a deterministic hash based job_id
        # Ensures a job with the same arguments from the same job class is unique.
        # @param job [ActiveJob::Base]
        # @return [String] unique id
        def self.generate_hash_id(job)
          class_name = job.class.name
          args = job.serialize['arguments']
          raise ArgumentError, 'args must be a hash or an array' unless args.is_a?(Hash) || args.is_a?(Array)

          args = DeepSort.deep_sort(args, sort_enum: true)
          json = JSON.generate(args)
          hash = Digest::MD5.hexdigest json
          "#{class_name}:#{hash}"
        end

        # Helper method for generating a query string style job_id.
        # Be conscious of key length, shorter keys are ideal.
        # @param job [ActiveJob::Base]
        # @param opts [Hash] - key value pairs to encode in the key hash
        def self.generate_keyed_id(job, opts)
          class_name = job.class.name
          raise ArgumentError, 'opts must be a non-empty hash' unless opts.is_a?(Hash) && opts.length.positive?

          key = DeepSort
                .deep_sort(opts, sort_enum: true)
                .map { |k, v| "#{k}=#{v.to_s.gsub(/[^-a-zA-z0-9_]+/, '-')}" }
                .join(':')
          key = "#{class_name}:#{key}"

          raise ArgumentError, "Generated key '#{key}'is too long" if key.length > 1024

          key
        end
      end
    end
  end
end
