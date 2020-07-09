class ChangeSavedSearchesStoredQueryToJsonb < ActiveRecord::Migration[6.0]
  def change
    reversible do |direction|
      change_table :saved_searches do |t|
        direction.up   { t.change :stored_query, :jsonb, using: 'stored_query::jsonb' }
        direction.down { t.change :stored_query, :text, using: 'stored_query::text' }
      end
    end
  end
end
