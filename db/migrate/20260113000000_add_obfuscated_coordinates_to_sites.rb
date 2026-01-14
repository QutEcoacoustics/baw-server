# frozen_string_literal: true

# Add obfuscated latitude and longitude to sites for privacy-preserving location data
class AddObfuscatedCoordinatesToSites < ActiveRecord::Migration[8.0]
  def change
    change_table :sites, bulk: true do |t|
      t.decimal :obfuscated_longitude, precision: 9, scale: 6
      t.decimal :obfuscated_latitude, precision: 9, scale: 6
    end

    add_index :sites, :obfuscated_latitude
    add_index :sites, :obfuscated_longitude
  end
end
