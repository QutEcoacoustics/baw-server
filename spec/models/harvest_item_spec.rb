# frozen_string_literal: true

RSpec.describe HarvestItem, type: :model do
  subject { FactoryBot.build(:harvest_item) }

  it 'has a valid factory' do
    expect(FactoryBot.create(:harvest_item)).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording).optional(true) }
  it { is_expected.to belong_to(:uploader).with_foreign_key(:uploader_id) }

  it { is_expected.to enumerize(:status).in(HarvestItem::STATUSES) }

  it 'encodes the info jsonb' do
    expect(HarvestItem.columns_hash['info'].type).to eq(:jsonb)
  end
end
