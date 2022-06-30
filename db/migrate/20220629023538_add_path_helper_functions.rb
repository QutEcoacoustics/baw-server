# frozen_string_literal: true

# Adds two functions used for manipulating paths in the database
# dirname - gets all but the last segment of a path
# path_contained_by_query - compares segments of a path to segments of query looking for matches.
#   Used to filter directories for children in a flat list of paths.
#   Returns the path at the current depth of the query if it matches - useful for grouping (all recursive) children.
class AddPathHelperFunctions < ActiveRecord::Migration[7.0]
  FUNCTIONS = <<~SQL
      CREATE OR REPLACE FUNCTION dirname(path text)
      RETURNS text
    AS
    $$
    DECLARE
      segments text[];
      length int;
    BEGIN
      segments := string_to_array(path, '/');
      length :=  CARDINALITY(segments) - 1;

      RETURN array_to_string(segments[1:length],'/');
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;

    CREATE OR REPLACE FUNCTION path_contained_by_query(path text, query text)
      RETURNS text
    AS
    $$
    DECLARE
      segments text[];
      query_segments text[];
      query_length int;
      segments_subset text[];
    BEGIN
      query := TRIM(BOTH '/' FROM query);
      query_segments := string_to_array(query, '/');
      query_length :=  CARDINALITY(query_segments);

      segments := string_to_array(path, '/');

      segments_subset := segments[1:query_length];
      IF query_segments <> segments_subset THEN
          RETURN NULL;
      END IF;


      RETURN array_to_string(segments[1:(query_length + 1)],'/');
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
  SQL

  def change
    reversible do |change|
      change.up do
        execute(FUNCTIONS)
      end
      change.down do
        execute(
                <<~SQL
                  DROP FUNCTION IF EXISTS "dirname";
                  DROP FUNCTION IF EXISTS "path_contained_by_query";
                SQL
              )
      end
    end
  end
end
