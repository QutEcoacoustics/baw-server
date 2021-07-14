# frozen_string_literal: true

module BawWorkers
  module Dry
    # The utility of StrictStruct but also defines a dynamic active job serializer
    # for an class that inherits from it.
    class SerializedStrictStruct < StrictStruct
      def self.inherited(sub_class)
        super

        # make an active job serializer specifically for this type
        serializer = create_serializer(sub_class)

        ActiveSupport.on_load(:active_job) do
          ::ActiveJob::Serializers.add_serializers << serializer
        end
      end

      def self.create_serializer(sub_class)
        unless sub_class.is_a?(Class) && sub_class.ancestors.include?(BawWorkers::Dry::StrictStruct)
          raise 'must inherit from strict struct'
        end

        klass = Class.new(::ActiveJob::Serializers::ObjectSerializer) do
          attr_accessor :target

          def serialize?(argument)
            argument.instance_of?(target)
          end

          def serialize(struct)
            hash = struct.as_json({ time_precision: 9 })
            super(hash)
          end

          def deserialize(hash)
            hash.delete(::ActiveJob::Arguments::OBJECT_SERIALIZER_KEY)
            target.new(hash)
          end
        end

        klass.instance.target = sub_class

        sub_class.const_set('Serializer', klass)
        klass
      end
    end
  end
end
