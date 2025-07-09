# frozen_string_literal: true

module Filter
  module Expressions
    # Converts UTC dates into some other timezone for comparison.
    class LocalTimezone < Expression
      def validate_type(type, model, _column_name)
        is_date = type == :datetime

        unless is_date
          raise CustomErrors::FilterArgumentError,
            "Expression function `local_offset` or `local_tz` is not compatible with type `#{type}`"
        end

        return if model_has_tz_relation?(model)

        raise CustomErrors::FilterArgumentError,
          "Cannot use `local_offset` or `local_tz` with the `#{model.name}` model because it does have timezone information"
      end

      def transform_value(node, model, _column_name, context)
        # don't do conversions on a value that isn't a date... a time will be
        # later in the pipeline and this timezone conversion is not appropriate
        return node unless context[:last]

        convert_to_local(node, get_tz_node(model))
      end

      def transform_field(node, model, _column_name)
        convert_to_local(node, get_tz_node(model))
      end

      def transform_query(model, _column_name)
        model.with_timezone => { joins: }

        lambda { |query|
          query.left_outer_joins(joins)
        }
      end

      def new_type
        :datetime
      end

      protected

      def model_has_tz_relation?(model)
        model.respond_to?(:with_timezone)
      end

      def get_tz_node(model)
        if model_has_tz_relation?(model)
          model.with_timezone => { model: relation_model, column: relation_column }
          return relation_model.arel_table[relation_column]
        end

        raise 'Unhandled case'
      end

      def convert_to_local(source_node, tz_node)
        # we must first tell postgres that the date in the database is UTC
        utc = Baw::Arel::Nodes::AsTimeZone.new(source_node, 'UTC')
        Baw::Arel::Nodes::AsTimeZone.new(utc, tz_node)
      end
    end
  end
end
