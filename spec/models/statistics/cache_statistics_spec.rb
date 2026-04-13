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

RSpec.describe Statistics::CacheStatistics do
  subject { build(:cache_statistics) }

  it 'has a valid factory' do
    expect(create(:cache_statistics)).to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:generated_at) }
  it { is_expected.to validate_numericality_of(:size_bytes).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:item_count).is_greater_than_or_equal_to(0).only_integer }

  it 'stores histogram as json' do
    histogram = [{ lower: 0.0, upper: 1024.0, count: 10 }]
    stat = create(:cache_statistics, histogram: histogram)

    expect(stat.reload.histogram).to match([{ 'lower' => 0.0, 'upper' => 1024.0, 'count' => 10 }])
  end
end
