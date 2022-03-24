# frozen_string_literal: true

module Filter
  module Expressions
    # Converts a UTC date to a local date using a consistent UTC offset.
    # The offset used is the "base" (the default, the unaltered) utc offset for a timezone.
    # Effectively this filter ignores DST.
    class LocalOffsetTimezone < LocalTimezone
      UTC_OFFSET_TABLE = Arel::Table.new(:offset_table)
      PG_TIMEZONE_NAMES = Arel::Table.new(:pg_timezone_names)
      BASE_OFFSET = :base_offset
      ONE_HOUR = Arel.sql("'3600 SECONDS'::interval")

      def transform_value(node, _model, _column_name, context)
        # don't do conversions on a value that isn't a date... a time will be
        # later in the pipeline and this timezone conversion is not appropriate
        return node unless context[:last]

        convert_to_local(node, UTC_OFFSET_TABLE[BASE_OFFSET])
      end

      def transform_field(node, _model, _column_name)
        convert_to_local(node, UTC_OFFSET_TABLE[BASE_OFFSET])
      end

      def transform_query(model, column)
        super_query = super(model, column)

        # create a CTE that pulls out the timezone offset
        lambda { |query|
          # join our main query with which ever table is providing tzinfo_tz column
          query = super_query.call(query)

          # if our query already has our lookup cte then we can skip adding it again
          return query if query.with_values.any? { |node| node&.left == UTC_OFFSET_TABLE }

          tz_column = get_tz_node(model)

          # add a CTE to generate a table of offsets
          offset_query = Arel::Nodes::As.new(
            UTC_OFFSET_TABLE,
            PG_TIMEZONE_NAMES
              .project(
                PG_TIMEZONE_NAMES[:name],
                (PG_TIMEZONE_NAMES[:is_dst]
                  .when(true).then(PG_TIMEZONE_NAMES[:utc_offset] - ONE_HOUR)
                  .else(PG_TIMEZONE_NAMES[:utc_offset])
                ).as(BASE_OFFSET.to_s)
              )
          )

          # Join our lookup table to the tzinfo_tz column
          # This is made possible with the activerecord-cte gem
          query
            .joins(model.arel_table.join(UTC_OFFSET_TABLE).on(tz_column.eq(UTC_OFFSET_TABLE[:name])).join_sources)
            .with(offset_query)
        }
      end
    end
  end
end
