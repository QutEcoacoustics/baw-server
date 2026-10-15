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

RSpec.describe Statistics::CacheStatistics do
  subject { build(:cache_statistics) }

  it 'has a valid factory' do
    expect(create(:cache_statistics)).to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:total_bytes) }
  it { is_expected.to validate_presence_of(:item_count) }
  it { is_expected.to validate_numericality_of(:total_bytes).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:item_count).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:minimum_bytes).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:maximum_bytes).is_greater_than_or_equal_to(0).only_integer }

  it 'stores size_histogram with bucket tuples' do
    histogram = [{ 'bucket' => [0.0, 1024.0], 'count' => 10 }]
    stat = create(:cache_statistics, size_histogram: histogram)

    expect(stat.reload.size_histogram).to match([{ 'bucket' => [0.0, 1024.0], 'count' => 10 }])
  end

  it 'returns typed HistogramBucket objects via typed_histogram' do
    histogram = [{ 'bucket' => [0.0, 1024.0], 'count' => 10 }]
    stat = create(:cache_statistics, size_histogram: histogram)

    buckets = stat.typed_histogram
    expect(buckets).to all(be_a(Statistics::CacheStatistics::HistogramBucket))
    expect(buckets.first.bucket).to eq([0.0, 1024.0])
    expect(buckets.first.count).to eq(10)
  end

  it 'returns nil from typed_histogram when size_histogram is nil' do
    stat = create(:cache_statistics, size_histogram: nil)
    expect(stat.typed_histogram).to be_nil
  end
end
