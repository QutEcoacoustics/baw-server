# frozen_string_literal: true

# Remove duplicate paths from harvest_items and add unique constraint to path
class AddPathUniqueToHarvestItems < ActiveRecord::Migration[7.2]
  def change
    reversible do |change|
      change.up do
        execute <<~SQL.squish
          WITH ranked_items AS (
              SELECT
                id,
                ROW_NUMBER() OVER (
                  PARTITION BY path
                  ORDER BY
                    (audio_recording_id IS NOT NULL) DESC,
                    pg_column_size(info) DESC
                ) AS keep_rank
              FROM harvest_items
            )
            DELETE FROM harvest_items
            WHERE id IN (
              SELECT id
              FROM ranked_items
              WHERE keep_rank > 1
            );
        SQL
        remove_index :harvest_items, :path
        add_index :harvest_items, :path, unique: true
      end

      change.down do
        remove_index :harvest_items, :path
        add_index :harvest_items, :path

        Rails.logger.warn(
          'This migration is backwards compatible but does not support reverse migration of the data
          as the duplicate records were necessarily deleted to add the unique constraint.
          `path` unique constraint reverted but no data has been changed.'
        )
      end
    end
  end
end
