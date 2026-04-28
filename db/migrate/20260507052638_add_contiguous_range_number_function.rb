# frozen_string_literal: true

# Adds the `contiguous_range_number` aggregate function to PostgreSQL.
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

        COMMENT ON TYPE contiguous_range_state IS '
        Accumulator state for contiguous_range_number.

        Fields:
          prev_range_upper - The greatest upper bound seen in the current contiguous block.
          sequence_number  - Zero-based label for the current contiguous block.
          threshold        - Maximum allowed gap before starting a new block.
        ';

        -- 2. Step function: advances the accumulator for each input range
        CREATE OR REPLACE FUNCTION contiguous_range_transition (
            state contiguous_range_state,
            current_range tsrange,
            threshold interval
        )
            RETURNS contiguous_range_state
            LANGUAGE plpgsql
            IMMUTABLE
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

        COMMENT ON FUNCTION contiguous_range_transition (contiguous_range_state, tsrange, interval) IS '
        Aggregate transition function for contiguous_range_number.

        Parameters:
          state         - Current accumulator state, or NULL for the first row.
          current_range - Current tsrange input value.
          threshold     - Maximum allowed gap between adjacent ranges.

        Returns:
          Updated contiguous_range_state with incremented sequence_number when the
          gap from the previous block exceeds threshold.
        ';

        -- 3. Final function: extracts the sequence number from the accumulator
        CREATE OR REPLACE FUNCTION contiguous_range_final (
            state contiguous_range_state
        )
            RETURNS bigint
            LANGUAGE sql
            IMMUTABLE
            AS $$
            SELECT
                state.sequence_number;
        $$;

        COMMENT ON FUNCTION contiguous_range_final (contiguous_range_state) IS '
        Aggregate final function for contiguous_range_number.

        Parameters:
          state - Final accumulator state after processing all rows.

        Returns:
          sequence_number from the final state.
        ';

        -- 4. Aggregate: groups tsranges into contiguous blocks by threshold
        CREATE OR REPLACE AGGREGATE contiguous_range_number (tsrange, interval) (
            SFUNC = contiguous_range_transition,
            STYPE = contiguous_range_state,
            FINALFUNC = contiguous_range_final
        );

        COMMENT ON AGGREGATE contiguous_range_number (tsrange, interval) IS '
        This aggregate assigns a monotonically increasing sequence number to each
        contiguous group of tsranges.

        Two ranges are considered contiguous (part of the same group) when the gap
        between them does not exceed a caller-supplied interval threshold.
        Whenever a gap exceeds the threshold the sequence number is incremented,
        effectively labelling each distinct contiguous block.

        This aggregate should be used in conjunction with an ORDER BY clause to ensure
        meaningful results.

        Parameters:
          tsrange  - Input range values, expected in ascending order
          interval - Gap threshold that defines contiguity.

        Returns:
          bigint zero-based contiguous block number for each aggregate group.
        ';
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
