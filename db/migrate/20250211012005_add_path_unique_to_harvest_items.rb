# frozen_string_literal: true

# Remove duplicate paths from harvest_items and add unique constraint to path
class AddPathUniqueToHarvestItems < ActiveRecord::Migration[7.2]
  # def change
  #   reversible do |change|
  #     change.up do
  #       execute <<~SQL.squish
  #         DELETE FROM harvest_items
  #         WHERE id IN (
  #           SELECT id
  #           FROM (
  #             SELECT id,
  #               ROW_NUMBER() OVER (PARTITION BY path ORDER BY created_at DESC) AS rn
  #             FROM harvest_items
  #           ) AS ranked
  #           WHERE ranked.rn > 1
  #         );
  #       SQL

  #       remove_index :harvest_items, :path
  #       add_index :harvest_items, :path, unique: true
  #     end

  #     change.down do
  #       remove_index :harvest_items, :path
  #       add_index :harvest_items, :path

  #       Rails.logger.warn(
  #         'This migration is backwards compatible but does not support reverse migration.
  #         `Path` unique constraint reverted but no data has been changed.'
  #       )
  #     end
  #   end
  # end
end
