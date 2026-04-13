# frozen_string_literal: true

# == Schema Information
#
# Table name: cache_statistics
#
#  id               :bigint           not null, primary key
#  name             :string           not null
#  size_bytes       :bigint           default(0), not null
#  item_count       :bigint           default(0), not null
#  min_item_size    :bigint
#  max_item_size    :bigint
#  mean_item_size   :decimal(20, 4)
#  std_dev_item_size :decimal(20, 4)
#  histogram        :jsonb
#  generated_at     :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_cache_statistics_on_name          (name)
#  index_cache_statistics_on_generated_at  (generated_at)
#
module Statistics
  # Stores statistics about a media cache.
  # Records are created by the CacheCleanupJob.
  class CacheStatistics < ApplicationRecord
    validates :name, presence: true
    validates :size_bytes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :item_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :generated_at, presence: true

    def self.filter_settings
      fields = [
        :id,
        :name,
        :size_bytes,
        :item_count,
        :min_item_size,
        :max_item_size,
        :mean_item_size,
        :std_dev_item_size,
        :histogram,
        :generated_at,
        :created_at,
        :updated_at
      ]
      {
        valid_fields: fields,
        render_fields: fields,
        text_fields: [:name],
        custom_fields2: {},
        controller: :cache_statistics,
        defaults: {
          order_by: :generated_at,
          direction: :desc
        },
        action: :index,
        capabilities: {},
        valid_associations: []
      }
    end

    def self.schema
      {
        type: :object,
        properties: {
          id: Api::Schema.id,
          name: { type: :string },
          size_bytes: { type: :integer, format: :int64 },
          item_count: { type: :integer, format: :int64 },
          min_item_size: { type: :integer, format: :int64, nullable: true },
          max_item_size: { type: :integer, format: :int64, nullable: true },
          mean_item_size: { type: :number, nullable: true },
          std_dev_item_size: { type: :number, nullable: true },
          histogram: {
            type: :array,
            nullable: true,
            items: {
              type: :object,
              properties: {
                lower: { type: :number },
                upper: { type: :number },
                count: { type: :integer }
              }
            }
          },
          generated_at: Api::Schema.date,
          created_at: Api::Schema.date,
          updated_at: Api::Schema.date
        },
        required: ['name', 'size_bytes', 'item_count', 'generated_at'],
        additionalProperties: false
      }
    end
  end
end
