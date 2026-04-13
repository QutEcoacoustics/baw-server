# frozen_string_literal: true

# Creates a table for storing media cache statistics.
class CreateCacheStatistics < ActiveRecord::Migration[7.2]
  def change
    create_table :cache_statistics do |t|
      t.string :name, null: false, comment: 'name of the cache (e.g. audio, spectrogram)'
      t.bigint :size_bytes, null: false, default: 0, comment: 'total size of all files in the cache in bytes'
      t.bigint :item_count, null: false, default: 0, comment: 'number of files in the cache (excluding directories)'
      t.bigint :min_item_size, null: true, comment: 'minimum file size in bytes'
      t.bigint :max_item_size, null: true, comment: 'maximum file size in bytes'
      t.decimal :mean_item_size, null: true, precision: 20, scale: 4, comment: 'mean file size in bytes'
      t.decimal :std_dev_item_size, null: true, precision: 20, scale: 4, comment: 'standard deviation of file sizes in bytes'
      t.jsonb :histogram, null: true, comment: '100-bucket histogram of individual file sizes'
      t.datetime :generated_at, null: false, comment: 'when these statistics were generated'

      t.timestamps
    end

    add_index :cache_statistics, :name
    add_index :cache_statistics, :generated_at
  end
end
