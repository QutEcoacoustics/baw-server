# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # A module that allows for slightly better typing of ActiveJob arguments
    module Arguments
      extend ActiveSupport::Concern
      # !@parse
      #   extend ClassMethods

      # ::nodoc::
      module ClassMethods
        #
        # Specify the types of the #perform function's arguments
        #
        # @raises [ArgumentError] if the wrong number of arguments are supplied
        # @param [Array<Class>] *types one or more classes that match the types and arity of the #perform method
        #
        # @return [void]
        #
        def perform_expects(*types)
          types.each do |type|
            raise ArgumentError, "The value `#{type}` is not a class" unless type.is_a?(Class)
          end

          self.perform_signature = types
        end
      end

      included do
        class_attribute :perform_signature, instance_accessor: true

        before_enqueue :validate_perform
        before_perform :validate_perform
      end

      private

      def validate_perform
        logger.debug('validating', arguments)

        parameters = self.class.instance_method(:perform).parameters
        arity = parameters.count
        signature = perform_signature

        raise 'perform_expects must be set before the job is run' if signature.nil? && arity.positive?

        unless arity == signature.count
          raise ArgumentError, "Arity of perform is #{arity} but #{signature.count} types were provided"
        end

        arg_count = arguments.count
        unless arity == arg_count
          raise ArgumentError, "Arity of perform is #{arity} but #{arg_count} args were provided"
        end

        parameters.each_with_index(&method(:validate_argument))
      end

      def validate_argument(parameter, index)
        logger.debug("validating#{parameter}")
        signature = self.class.perform_signature
        arg_type, name = parameter
        type = signature[index]

        case arg_type
        when :req then arguments[index]
        when :keyreq then arguments.last[name]
        else raise "Unexpected argument type for job arguments: `#{arg_type}``, named: `#{name}`"
        end => arg

        return if arg.nil? || arg.instance_of?(type)

        raise TypeError, "Argument (`#{arg.class}`) for parameter `#{name}` does not have expected type `#{type}`"
      end
    end
  end
end
