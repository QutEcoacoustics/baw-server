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
FactoryBot.define do
  factory :cache_statistics, class: 'Statistics::CacheStatistics' do
    name { 'audio' }
    size_bytes { 1_073_741_824 } # 1 GB
    item_count { 100 }
    min_item_size { 1024 }
    max_item_size { 10_485_760 }
    mean_item_size { 524_288.0 }
    std_dev_item_size { 120_000.0 }
    histogram { nil }
    generated_at { Time.zone.now }
  end
end
