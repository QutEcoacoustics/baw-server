# frozen_string_literal: true

# Adds a PostgreSQL function to extract the basename from a file path.
class BasenameFunction < ActiveRecord::Migration[8.0]
  # rubocop:disable Rails/SquishedSQLHeredocs
  FUNCTIONS = <<~SQL
    CREATE OR REPLACE FUNCTION basename(path text)
    RETURNS text
    AS
    $$
    DECLARE
      segments text[];
      length int;
    BEGIN
      IF path IS NULL THEN
        RETURN NULL;
      END IF;

      segments := string_to_array(path, '/');
      length := CARDINALITY(segments);

      IF length = 0 THEN
        RETURN NULL;
      END IF;

      RETURN segments[length];
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
  SQL
  # rubocop:enable Rails/SquishedSQLHeredocs

  def up
    execute(FUNCTIONS)
  end

  def down
    execute('DROP FUNCTION IF EXISTS basename;')
  end
end
