# frozen_string_literal: true

# Widen the used_memory_bytes column in the analysis_jobs_items table from integer to bigint
# This migration is necessary to accommodate larger memory usage values that have been encountered.
class WidenUsedMemoryBytes < ActiveRecord::Migration[7.2]
  def change
    reversible do |dir|
      dir.up do
        change_column :analysis_jobs_items, :used_memory_bytes, :bigint
      end

      dir.down do
        change_column :analysis_jobs_items, :used_memory_bytes, :integer
      end
    end
  end
end
