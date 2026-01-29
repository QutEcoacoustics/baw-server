# frozen_string_literal: true

# Add obfuscated latitude and longitude to sites for privacy-preserving location data.
# The backfill job is automatically enqueued after the migration commits.
class AddObfuscatedCoordinatesToSites < ActiveRecord::Migration[8.0]
  def change
    change_table :sites, bulk: true do |t|
      t.decimal :obfuscated_longitude, precision: 9, scale: 6
      t.decimal :obfuscated_latitude, precision: 9, scale: 6
      t.boolean :custom_obfuscated_location, default: false, null: false,
        comment: 'True if the obfuscated location was set by the user or false if generated'
    end

    add_index :sites, :obfuscated_latitude
    add_index :sites, :obfuscated_longitude

    # Drop jitter SQL functions if they exist from a previous migration attempt
    reversible do |dir|
      dir.up do
        execute 'DROP FUNCTION IF EXISTS obfuscate_location(numeric, numeric, numeric, text, numeric, boolean);'
        execute 'DROP FUNCTION IF EXISTS sample_two_immutable_randoms(text, numeric);'
        execute 'DROP FUNCTION IF EXISTS clamp(numeric, numeric, numeric);'
      end
    end

    up_only do
      # Enqueue the backfill job after the migration transaction commits
      # Wait a minute to ensure workers are ready
      BawWorkers::Jobs::Maintenance::BackfillSitesObfuscatedLocationsJob.set(wait: 2.minutes).perform_later
    end
  end
end
