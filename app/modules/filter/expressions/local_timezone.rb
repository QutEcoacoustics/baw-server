# frozen_string_literal: true

module Filter
  module Expressions
    # Covnerts UTC dates into some other timezone for comparison.
    class LocalTimezone < Expression
      def validate_type(type, model, _column_name)
        is_date = type == :datetime

        unless is_date
          raise CustomErrors::FilterArgumentError,
            "Expression function `local_offset` or `local_tz` is not compatible with type `#{type}`"
        end

        return if model_has_tz?(model) || model_has_tz_scope?(model)

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

      def transform_query(model, column_name)
        return super(model, column_name) if model_has_tz?(model)

        lambda { |query|
          model.with_timezone(query)
        }
      end

      def new_type
        :datetime
      end

      protected

      def model_has_tz?(model)
        model.columns_hash.key?('tzinfo_tz')
      end

      def model_has_tz_scope?(model)
        model.respond_to?(:with_timezone)
      end

      def get_tz_node(model)
        return model.arel_table['tzinfo_tz'] if model_has_tz?(model)

        return ::Arel::Nodes::UnqualifiedColumn.new(:tzinfo_tz) if model_has_tz_scope?(model)

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
