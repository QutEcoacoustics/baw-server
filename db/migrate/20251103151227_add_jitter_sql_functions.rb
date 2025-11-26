# frozen_string_literal: true

# Adds a location obfuscation SQL functions to the database
class AddJitterSqlFunctions < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        execute UP
      end

      dir.down do
        execute <<~SQL
          DROP FUNCTION IF EXISTS obfuscate_location;
          DROP FUNCTION IF EXISTS sample_two_immutable_randoms;
          DROP FUNCTION IF EXISTS clamp;
        SQL
      end
    end
  end
end

# rubocop:disable Layout/HeredocIndentation
UP = <<~SQL
CREATE OR REPLACE FUNCTION clamp(value numeric, minimum numeric, maximum numeric)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
RETURNS NULL ON NULL INPUT
AS $$
BEGIN
  RETURN GREATEST(minimum, LEAST(maximum, value));
END;
$$;

-- ==============================================================
-- clamp
-- ==============================================================
COMMENT ON FUNCTION clamp(value numeric, minimum numeric, maximum numeric) IS
$$
Clamps a numeric value between a minimum and maximum.

Parameters:
  value   - The numeric value to clamp.
  minimum - The lower bound of the clamping range.
  maximum - The upper bound of the clamping range.

Returns:
  The value constrained to the [minimum, maximum] interval.
$$;

CREATE OR REPLACE FUNCTION sample_two_immutable_randoms(
  seed text,
  exclusion numeric DEFAULT 0.0,
  a OUT numeric,
  b OUT numeric
)
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  hash varchar(40);
  int64_max CONSTANT bigint DEFAULT 9223372036854775807;
BEGIN
  -- the sha1 is a cryptographic hash function so should be well distributed
  -- the digest is 160 bits (40 hex characters)
  hash := encode(digest(seed::text,'sha1'), 'hex');

  -- samples two 8 byte integers from the digest to get two random-ish numbers
  -- we convert to bigint then to numeric and scale to [-1, 1]
  a := (('x' || substr(hash, 1, 16))::bit(64)::bigint)::numeric / int64_max;
  b := (('x' || substr(hash, 17, 16))::bit(64)::bigint)::numeric / int64_max;

  --rescale the random values if both are within the exclusion zone
  IF (abs(a) < exclusion) AND (abs(b) < exclusion) THEN
    -- what we do here is we take the value that's in the exclusion zone and
    -- stretch it out over the valid zone instead.
    -- e.g. 0.05 is half of an 0.1 exclusion zone. The valid zone is [0.1, 1.0] (|0.9|).
    -- Half way along that interval is 0.45.
    a := (sign(a) + (a = 0)::int) * (((1 - exclusion) * (abs(a)/exclusion)) + exclusion);
    b := (sign(b) + (b = 0)::int) * (((1 - exclusion) * (abs(b)/exclusion)) + exclusion);
  END IF;
END
$$;

COMMENT ON FUNCTION sample_two_immutable_randoms(seed text, exclusion numeric) IS
$$
Generates two deterministic pseudo-random numbers in the range [-1, -exclusion] ∩ [exclusion, 1] based on a seed string.

Parameters:
  seed      - A text string used to generate deterministic random numbers.
  exclusion - Optional fraction of the unit interval (0.0 - 1.0) to define an exclusion zone around 0.
              If both random numbers fall inside this exclusion zone, they are scaled outward to avoid it.

Returns:
  A scalar composite type with fields:
    a - A pseudo-random number in [-1, -exclusion] ∩ [exclusion, 1].
    b - A pseudo-random number in [-1, -exclusion] ∩ [exclusion, 1].
Behavior:
  - Deterministic: same seed and exclusion always produce the same output.
  - Optional exclusion zone ensures that small random numbers near 0 can be pushed outward.
IMMUTABLE.
$$;

CREATE OR REPLACE FUNCTION obfuscate_location(
  latitude         INOUT  numeric,
  longitude        INOUT  numeric,
  jitter_amount           numeric,
  salt                    text,
  jitter_exclusion        numeric DEFAULT 0.1,
  obfuscated       INOUT  boolean DEFAULT true
)
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  random_a numeric;
  random_b numeric;
BEGIN
  -- why include the option to not obfuscate?
  -- it makes calling and using this function easier. We can just
  -- pass in a result from e.g. a permissions test on whether or not
  -- to obfuscate and we don't need a conditional at every calling site
  IF obfuscated THEN
    -- set seed as simple concatenation of the latitude and longitude and salt
    -- our random number is deterministic and can also exclude ranges around 0
    SELECT a, b INTO random_a, random_b FROM
    sample_two_immutable_randoms(
      (COALESCE(latitude, 0.0))::text || (COALESCE(longitude, 0.0))::text || jitter_amount::text || salt,
      jitter_exclusion
    );

    -- apply jitter to each component, and clamp to valid range
    -- leave nulls unaffected
    IF latitude IS NOT NULL THEN
      latitude := round(clamp(latitude + (random_a * jitter_amount), -90.0, 90.0), 6);
    END IF;

    IF longitude IS NOT NULL THEN
      longitude := round(clamp(longitude + (random_b * jitter_amount), -180.0, 180.0), 6);
    END IF;
  END IF;
END;
$$;

COMMENT ON FUNCTION obfuscate_location(
    numeric, numeric, numeric, text, numeric, boolean
) IS
$$
Obfuscates geographic coordinates (latitude and longitude) by applying a deterministic jitter.

Parameters:
  latitude         - Original latitude in decimal degrees.
  longitude        - Original longitude in decimal degrees.
  jitter_amount    - Maximum magnitude of jitter to apply.
  salt             - Seed text to make obfuscation deterministic per row or entity.
  jitter_exclusion - Fraction of the unit interval [0, 1] representing an exclusion zone around 0
                     where random jitter values are pushed outward (default 0.1).
  obfuscated       - Boolean flag; if false, returns original coordinates without modification (default true).

Returns:
  A scalar composite type with fields:
    latitude  - The obfuscated latitude.
    longitude - The obfuscated longitude.
    obfuscated - Boolean indicating whether the output was actually obfuscated.

Behavior:
  - Deterministic: same inputs (including salt) always produce the same output.
  - Leaves NULL coordinates unaffected.
  - Applies clamping to ensure latitude stays within [-90, 90] and longitude within [-180, 180].
  - Rounds results to 6 decimal places.
$$;
SQL
# rubocop:enable Layout/HeredocIndentation

# Testing functions
#-- select s.n, r.*
#-- from generate_series(-1000, 2000) s(n)
#-- cross join LATERAL  sample_two_immutable_randoms(s.n::text, 0.1) r
#
#select id, name, sites.latitude, sites.longitude, location.*, sites.latitude - location.latitude as latitude_delta, sites.longitude - location.longitude as longitude_delta
#from sites
#CROSS JOIN LATERAL  obfuscate_location(latitude::numeric, longitude::numeric, 0.033::numeric, id::text, 0.1, true) AS location
#order by id desc
#--limit 100;
