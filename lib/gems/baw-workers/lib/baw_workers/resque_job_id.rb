# frozen_string_literal: true

module BawWorkers
  # Create and manage resque job ids.
  class ResqueJobId
    class << self
      # Create a payload with an id based on the class and args.
      # WARNING: The order of of values in args is important.
      # @param [String] klass
      # @param [Hash] args
      # @return [Hash] payload
      def create_payload(klass, args = {})
        resque_status_id = create_id_props(klass, args)
        payload = { class: normalise_class(klass), args: [resque_status_id] + normalise_args(args) }
        normalise(payload)
      end

      # Get an id from payload (name of class, args hash).
      # WARNING: The order of of values in args is important.
      # @param [Hash] payload
      # @return [String] id
      def create_id_payload(payload)
        klass = get_class(payload)
        args = get_args(payload)

        create_id_props(klass, args)
      end

      # Create an id from class and args.
      # WARNING: The order of of values in args is important.
      # @param [String] klass
      # @param [Hash] args
      # @return [String] id
      def create_id_props(klass, args = {})
        normalised_class = normalise_class(klass)
        normalised_args = normalise_args(args)

        generate(normalised_class, normalised_args)
      end

      # Get the class from a payload.
      # @param [Hash] payload
      # @return [String] class name
      def get_class(payload)
        payload[:class] || payload['class']
      end

      # Get the args from a payload.
      # @param [Hash] payload
      # @return [Hash, Array] args
      def get_args(payload)
        payload[:args] || payload['args']
      end

      # Normalise the class.
      # @param [Class] klass
      # @return [String] normalised class representation
      def normalise_class(klass)
        normalise(klass.to_s)
      end

      # Normalise the class.
      # @param [Hash] args
      # @return [Array] normalised args array
      def normalise_args(args = {})
        normalise(args.to_a)
      end

      # Normalise an object.
      # @param [Object] value
      # @return [Object] normalised object
      def normalise(value)
        Resque.decode(Resque.encode(value))
      end

      # Create an id from class and args.
      # Class and args must have already been normalised.
      # @param [String] klass
      # @param [Array<Hash, Object>] args
      # @return [String] unique id
      def generate(klass, args = [])
        # HACK: I don't know what this ever sorts, but it is important that it doesn't work - sometimes
        args.map! do |arg|
          if arg.is_a?(Hash)
            arg.sort
          else
            arg
          end
        end

        # payload must not include id itself - otherwise id will not match
        modified_args = args.deep_dup
        modified_args.delete_at(0) if !modified_args.empty? && modified_args[0].is_a?(String)

        # ensure args are not nested in another array
        if modified_args.size == 1 && modified_args[0].is_a?(Array) && modified_args[0][0].is_a?(Array)
          modified_args = modified_args[0]
        end

        # sort the arg array by the first item in each sub-array
        modified_args = modified_args.sort { |a, b|
          a[0] <=> b[0]
        }

        Digest::MD5.hexdigest Resque.encode(class: klass, args: modified_args)
      end
    end
  end
end
