# frozen_string_literal: true

# == Schema Information
#
# Table name: cache_statistics
#
#  id                       :bigint           not null, primary key
#  name                     :string           not null
#  total_bytes              :bigint           default(0), not null
#  item_count               :bigint           default(0), not null
#  minimum_bytes            :bigint
#  maximum_bytes            :bigint
#  mean_bytes               :decimal(20, 4)
#  standard_deviation_bytes :decimal(20, 4)
#  size_histogram           :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_cache_statistics_on_name                 (name)
#  index_cache_statistics_on_name_and_created_at  (name, created_at) UNIQUE
#
module Statistics
  # Stores statistics about a media cache at a point in time.
  # Records are created by BawWorkers::Jobs::Cache::CacheCleanupJob.
  class CacheStatistics < ApplicationRecord
    # A single bucket of a file-size histogram.
    # - +bucket+: two-element array [lower_bound, upper_bound] in bytes
    # - +count+: number of files whose size falls in this bucket
    HistogramBucket = ::Data.define(:bucket, :count)

    validates :name, presence: true
    validates :total_bytes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :item_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :minimum_bytes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :maximum_bytes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :mean_bytes, numericality: true, allow_nil: true
    validates :standard_deviation_bytes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :name, uniqueness: { scope: :created_at }

    # Returns the size_histogram as an array of HistogramBucket value objects.
    # Returns nil if no histogram is stored.
    # @return [Array<HistogramBucket>, nil]
    def typed_histogram
      return nil if size_histogram.nil?

      size_histogram.map { |h|
        HistogramBucket.new(bucket: h['bucket'], count: h['count'])
      }
    end

    def self.filter_settings
      fields = [
        :id,
        :name,
        :total_bytes,
        :item_count,
        :minimum_bytes,
        :maximum_bytes,
        :mean_bytes,
        :standard_deviation_bytes,
        :size_histogram,
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
          order_by: :created_at,
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
          total_bytes: { type: :integer, format: :int64 },
          item_count: { type: :integer, format: :int64 },
          minimum_bytes: { type: :integer, format: :int64, nullable: true },
          maximum_bytes: { type: :integer, format: :int64, nullable: true },
          mean_bytes: { type: :number, nullable: true },
          standard_deviation_bytes: { type: :number, nullable: true },
          size_histogram: {
            type: :array,
            nullable: true,
            items: {
              type: :object,
              properties: {
                bucket: {
                  type: :array,
                  items: { type: :number },
                  minItems: 2,
                  maxItems: 2
                },
                count: { type: :integer }
              }
            }
          },
          created_at: Api::Schema.date,
          updated_at: Api::Schema.date
        },
        required: ['name', 'total_bytes', 'item_count'],
        additionalProperties: false
      }
    end
  end
end
