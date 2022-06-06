# frozen_string_literal: true

# Update the harvest table to record more date stamps
class AddColumnsToHarvest < ActiveRecord::Migration[7.0]
  def change
    change_table :harvests do |t|
      t.datetime :last_metadata_review_at
      t.datetime :last_mappings_change_at

      # rename for consistency with out other date columns
      t.rename :last_upload_date, :last_upload_at
    end
  end
end
