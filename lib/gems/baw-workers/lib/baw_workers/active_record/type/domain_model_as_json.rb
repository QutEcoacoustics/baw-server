# frozen_string_literal: true

module BawWorkers
  module ActiveRecord
    module Type
      # support for active record attributes
      # stolen from:
      # https://github.com/rails/rails/blob/c338c66f84d847f3ddf06d3e064426c7991e553d/activerecord/lib/active_record/type/internal/abstract_json.rb#L4
      class DomainModelAsJson < ::ActiveRecord::Type::Json
        attr_reader :target_class, :ignore_nil

        # Target class must accept a hash as its first parameter
        # and then convert to it's target type
        # @param target_class [Class] the class to convert to
        # @param ignore_nil [Boolean] whether to ignore nil values - if true the class
        #   constructor will not be called
        def initialize(target_class:, ignore_nil: false)
          @target_class = target_class
          @ignore_nil = ignore_nil
          super()
        end

        def deserialize(value)
          deserialized = super(value)
          return nil if ignore_nil && deserialized.nil?

          target_class.new(deserialized)
        end

        # rubocop:disable Lint/UselessMethodDefinition
        def serialize(value)
          # noop currently, we expect the value to provide an as_json method
          super(value)
        end
        # rubocop:enable Lint/UselessMethodDefinition
      end
    end
  end
end
