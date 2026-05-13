# frozen_string_literal: true

# Adds a PostgreSQL function `tsmultirange_total_seconds` that accepts a
# `tsmultirange` and returns the sum of each constituent `tsrange`'s duration in
# seconds as a double precision value.
#
# Example use case is to input the tsmultirange returned by 'range_agg', to get
# the total non-overlapping seconds covered by the tsmultirange. This is useful
# because it saves having to handle unnesting the tsmultirange and simplifies the query.
class AddTsmultirangeTotalSecondsFunction < ActiveRecord::Migration[8.0]
  def up
    execute(
      <<~SQL
        CREATE OR REPLACE FUNCTION tsmultirange_total_seconds (
            multirange tsmultirange
        )
            RETURNS double precision
            LANGUAGE sql
            IMMUTABLE
            PARALLEL SAFE
            AS $$
            SELECT
                extract(epoch FROM sum(upper(time_range) - lower(time_range)))
            FROM
                unnest(multirange) AS time_range
        $$;
      SQL
    )
  end

  def down
    execute('DROP FUNCTION IF EXISTS tsmultirange_total_seconds(tsmultirange)')
  end
end
