# frozen_string_literal: true

class AddIndexesToHarvestTables < ActiveRecord::Migration[7.0]
  def change
    add_index :harvest_items, :harvest_id
    add_index :harvest_items, :info, using: 'gin'
  end
end
