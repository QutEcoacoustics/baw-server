class ChangeTagNotesToJson < ActiveRecord::Migration
  def change
    # https://www.citusdata.com/blog/2016/07/14/choosing-nosql-hstore-json-jsonb/
    execute <<~SQL
      CREATE OR REPLACE FUNCTION pg_temp.is_json(varchar) RETURNS boolean AS $$
        DECLARE
          x json;
        BEGIN
          BEGIN
            x := $1;
          EXCEPTION WHEN others THEN
            RETURN FALSE;
          END;
          RETURN TRUE;
        END;
      $$ LANGUAGE plpgsql IMMUTABLE;

      ALTER TABLE "tags"
        ALTER COLUMN "notes" TYPE jsonb
        USING CASE
          WHEN notes is NULL THEN '{}'::json
          WHEN notes = '' THEN '{}'::json
          WHEN pg_temp.is_json(notes) THEN notes::json
          ELSE json_build_object('comment', notes)
        END
    SQL
  end
end
