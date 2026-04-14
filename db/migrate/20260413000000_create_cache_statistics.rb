# frozen_string_literal: true

# Creates a table for storing media cache statistics.
class CreateCacheStatistics < ActiveRecord::Migration[7.2]
  def change
    create_table :cache_statistics do |t|
      t.string :name, null: false, comment: 'name of the cache (e.g. audio, spectrogram)'
      t.bigint :total_bytes, null: false, default: 0, comment: 'total size of all files in the cache in bytes'
      t.bigint :item_count, null: false, default: 0, comment: 'number of files in the cache (excluding directories)'
      t.bigint :minimum_bytes, null: true, comment: 'minimum file size in bytes'
      t.bigint :maximum_bytes, null: true, comment: 'maximum file size in bytes'
      t.decimal :mean_bytes, null: true, precision: 20, scale: 4, comment: 'mean file size in bytes'
      t.decimal :standard_deviation_bytes, null: true, precision: 20, scale: 4, comment: 'standard deviation of file sizes in bytes'
      t.jsonb :size_histogram, null: true, comment: '100-bucket histogram of individual file sizes'

      t.timestamps
    end

    add_index :cache_statistics, :name
    add_index :cache_statistics, :created_at
  end
end
