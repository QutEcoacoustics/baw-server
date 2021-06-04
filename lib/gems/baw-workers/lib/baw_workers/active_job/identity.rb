# frozen_string_literal: true

require 'securerandom'

module BawWorkers
  module ActiveJob
    # A module that ensures an ActiveJob implements a name and job_id
    module Identity
      extend ActiveSupport::Concern

      included do
        raise TypeError, 'must be included in an ActiveJob::Base' unless is_a?(ActiveJob::Base)
      end

      # Produces a sensible friendly name for this payload, shown in UIs.
      # Should be unique but does not need to be. Has no operational effect.
      # Abstract, your job should override.
      # @param job [ActiveJob::Base]
      # @return [String]
      def name(_job)
        raise NotImplementedError, "You must implement #{__method__} in your job class."
      end

      # Produces a unique key to ensure uniqueness of this job.
      # See IdHelpers module methods for examples job_id generators you can use.
      # @param job [ActiveJob::Base]
      # @return [String]
      def job_id(_job)
        raise NotImplementedError, "You must implement #{__method__} in your job class."
      end

      class_methods do
      end
    end

    module AutoIdentity
      extend Identity

      def name(job)
        "#{job_id}"
      end

      def job_id(job)
        IdHelpers.generate_uuid
      end
    end

    module IdHelpers
      # Helper method for generating a random job_id
      # Ensures that every job is unique.
      # @return [String]
      def generate_uuid
        key = SecureRandom.hex.to_s
        "#{class_name}:#{key}"
      end

      # Helper method for generating a deterministic hash based job_id
      # Ensures a job with the same arguments from the same job class is unique.
      # @param [String] klass
      # @param [Array<Hash, Object>] args
      # @return [String] unique id
      def generate_hash_id(class_name, args)
        raise ArgumentError, 'args must be a hash or an array' unless args.is_a?(Hash) || args.is_a?(Array)

        args.deepsort!
        json = ActiveJob.arguments.serialize(args)
        hash = Digest::MD5.hexdigest json
        "#{class_name}:#{hash}"
      end

      def generate_keyed_id(class_name, opts)
        raise ArgumentError, 'class_name must be a string' unless class_name.is_a?(String)
        raise ArgumentError, 'opts must be a non-empty hash' unless opts.is_a?(Hash) && opts.length.positive?

        key = hash
          .sort
          .map { |k, v| "#{k}=#{v}" }
          .join(':')

        "#{class_name}:#{key}"

      end
    end
  end
end
