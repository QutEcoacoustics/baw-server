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
FactoryBot.define do
  factory :cache_statistics, class: 'Statistics::CacheStatistics' do
    name { 'audio' }
    total_bytes { 1_073_741_824 } # 1 GB
    item_count { 100 }
    minimum_bytes { 1024 }
    maximum_bytes { 10_485_760 }
    mean_bytes { 524_288.0 }
    standard_deviation_bytes { 120_000.0 }
    size_histogram { nil }
  end
end
