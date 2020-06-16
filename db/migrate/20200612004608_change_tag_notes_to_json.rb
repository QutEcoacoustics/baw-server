class ChangeTagNotesToJson < ActiveRecord::Migration
  def change
    # https://www.citusdata.com/blog/2016/07/14/choosing-nosql-hstore-json-jsonb/
    change_column :tags, :notes, :jsonb, using: <<~SQL
      CASE
        WHEN notes is NULL
          THEN \'{}\'::json
        WHEN notes = \'\'
          THEN \'{}\'::json
        ELSE json_build_object(\'comment\', notes)
      END
    SQL
  end
end
