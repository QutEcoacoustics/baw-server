# frozen_string_literal: true

module Filter
  module Expressions
    class TimeOfDay < Expression
      def validate_type(type, _model, _column_name)
        return if type == :datetime

        raise CustomErrors::FilterArgumentError,
          "Expression function `time_of_day` is not compatible with type `#{type}`"
      end

      def transform_value(node, _model, _column_name, context)
        raw_value = context[:raw_value]
        unless raw_value.is_a?(String) && raw_value =~ /^\d\d:\d\d(:\d\d(\.\d+)?)?$/
          raise CustomErrors::FilterArgumentError,
            "Expression time_of_day must be supplied with a time, got `#{raw_value}`"
        end

        node.cast('time')
      end

      def transform_field(node, _model, _column_name)
        node.cast('time')
      end

      def new_type
        :time
      end
    end
  end
end
