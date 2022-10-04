# frozen_string_literal: true

# Adds a name column to harvest tables.
# Auto fills in a default value.
class AddNameToHarvests < ActiveRecord::Migration[7.0]
  def change
    change_table :harvests do |t|
      t.string :name, null: true
    end
  end
end
