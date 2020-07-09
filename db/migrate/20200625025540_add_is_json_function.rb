class AddIsJsonFunction < ActiveRecord::Migration[6.0]
  def up
    execute(
      <<~SQL
        CREATE OR REPLACE FUNCTION is_json(input TEXT) RETURNS boolean AS $$
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
      SQL
    )
  end

  def down
    execute(
      <<~SQL
        DROP FUNCTION IF EXISTS "is_json"
      SQL
    )
  end
end
