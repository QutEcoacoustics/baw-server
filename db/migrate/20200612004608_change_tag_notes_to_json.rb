class ChangeTagNotesToJson < ActiveRecord::Migration
  def change
    # https://www.citusdata.com/blog/2016/07/14/choosing-nosql-hstore-json-jsonb/
    execute <<~SQL
      CREATE OR REPLACE FUNCTION pg_temp.is_json(input TEXT) RETURNS boolean AS $$
        DECLARE
          data json;
        BEGIN
          BEGIN
            data := input;
          EXCEPTION WHEN others THEN
            RETURN FALSE;
          END;
          RETURN TRUE;
        END;
      $$ LANGUAGE plpgsql IMMUTABLE;

      ALTER TABLE "tags"
        ALTER COLUMN "notes" TYPE jsonb
        USING CASE
          WHEN (notes <> '') is NOT TRUE
            THEN NULL
          WHEN pg_temp.is_json(notes) AND json_typeof(notes::json) = 'object'
            THEN notes::json
          WHEN pg_temp.is_json(notes) AND NOT json_typeof(notes::json) = 'string'
            THEN json_build_object('comment', notes::json)
          ELSE json_build_object('comment', notes)
      END
    SQL
  end
end
