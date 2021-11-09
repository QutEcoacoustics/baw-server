# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (uploader_id => users.id)
#
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

  it 'deserializes the info column as hash with indifferent access' do
    item = FactoryBot.build(:harvest_item)
    item.info[:hello] = 123
    item.save!

    item = HarvestItem.find(item.id)

    expect(item.info).to be_an_instance_of(HashWithIndifferentAccess)
    expect(item.info['hello']).to eq 123
    expect(item.info[:hello]).to eq 123
  end
end
