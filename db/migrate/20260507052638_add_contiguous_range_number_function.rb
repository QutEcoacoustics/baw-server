# frozen_string_literal: true

# Adds the `contiguous_range_number` aggregate function to PostgreSQL.
#
# This aggregate assigns a monotonically increasing sequence number to each
# contiguous group of tsranges. Two ranges are considered contiguous (part of
# the same group) when the gap between them does not exceed a caller-supplied
# interval threshold. Whenever a gap exceeds the threshold the sequence number
# is incremented, effectively labelling each distinct contiguous block.
#
# Objects created (in dependency order):
#   1. Type      contiguous_range_state        – accumulator state
#   2. Function  contiguous_range_transition   – aggregate step function
#   3. Function  contiguous_range_final        – aggregate final function
#   4. Aggregate contiguous_range_number       – the public aggregate
class AddContiguousRangeNumberFunction < ActiveRecord::Migration[8.0]
  def up
    execute(
      <<~SQL
        -- 1. Accumulator state type
        CREATE TYPE contiguous_range_state AS (
            prev_range_upper timestamp,
            sequence_number bigint,
            threshold interval
        );

        -- 2. Step function: advances the accumulator for each input range
        CREATE OR REPLACE FUNCTION contiguous_range_transition (
            state contiguous_range_state,
            current_range tsrange,
            threshold interval
        )
            RETURNS contiguous_range_state
            LANGUAGE plpgsql
            AS $$
        BEGIN
            IF state IS NULL THEN
                RETURN ROW (upper(current_range),
                    0,
                    threshold)::contiguous_range_state;

            END IF;

            IF lower(current_range) > state.prev_range_upper + state.threshold THEN
                RETURN ROW (upper(current_range),
                    state.sequence_number + 1,
                    state.threshold)::contiguous_range_state;

            ELSE
                RETURN ROW (GREATEST (upper(current_range), state.prev_range_upper),
                    state.sequence_number,
                    state.threshold)::contiguous_range_state;

            END IF;

        END;

        $$;

        -- 3. Final function: extracts the sequence number from the accumulator
        CREATE OR REPLACE FUNCTION contiguous_range_final (
            state contiguous_range_state
        )
            RETURNS bigint
            LANGUAGE sql
            AS $$
            SELECT
                state.sequence_number;
        $$;

        -- 4. Aggregate: groups tsranges into contiguous blocks by threshold
        CREATE AGGREGATE contiguous_range_number (tsrange, interval) (
            SFUNC = contiguous_range_transition,
            STYPE = contiguous_range_state,
            FINALFUNC = contiguous_range_final
        );

      SQL
    )
  end

  def down
    execute(
      <<~SQL
        DROP AGGREGATE IF EXISTS contiguous_range_number (tsrange, interval);
        DROP FUNCTION IF EXISTS contiguous_range_final (contiguous_range_state);
        DROP FUNCTION IF EXISTS contiguous_range_transition (contiguous_range_state, tsrange, interval);
        DROP TYPE IF EXISTS contiguous_range_state;
      SQL
    )
  end
end
