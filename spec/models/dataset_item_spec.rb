# frozen_string_literal: true

# == Schema Information
#
# Table name: dataset_items
#
#  id                 :integer          not null, primary key
#  end_time_seconds   :decimal(, )      not null
#  order              :decimal(, )
#  start_time_seconds :decimal(, )      not null
#  created_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer
#  dataset_id         :integer
#
# Indexes
#
#  dataset_items_idx  (start_time_seconds,end_time_seconds)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#
RSpec.describe DatasetItem, type: :model do
  subject { FactoryBot.build(:dataset_item) }

  it 'has a valid factory' do
    expect(FactoryBot.create(:dataset_item)).to be_valid
  end

  it 'is invalid if the dataset_id is missing' do
    expect(build(:dataset_item, { dataset_id: nil })).not_to be_valid
  end

  it 'is invalid if the audio_recording_id is missing' do
    expect(build(:dataset_item, { audio_recording_id: nil })).not_to be_valid
  end

  it 'is invalid if the start time is less than zero' do
    expect(build(:dataset_item, { start_time_seconds: -0.01 })).not_to be_valid
  end

  it 'is invalid if the end time is before the start time' do
    expect(build(:dataset_item, { start_time_seconds: 123, end_time_seconds: 121 })).not_to be_valid
  end

  it 'is invalid if order is not numeric' do
    expect(build(:dataset_item, { order: 'abc' })).not_to be_valid
  end

  it 'is valid if order is empty' do
    expect(build(:dataset_item, { order: nil })).to be_valid
    expect(build(:dataset_item, { order: '' })).to be_valid
  end

  it 'is valid if order is numeric' do
    expect(build(:dataset_item, { order: -1234 })).to be_valid
    expect(build(:dataset_item, { order: -1234.5678 })).to be_valid
    expect(build(:dataset_item, { order: 0 })).to be_valid
    expect(build(:dataset_item, { order: 0.0 })).to be_valid
    expect(build(:dataset_item, { order: 0.0001 })).to be_valid
    expect(build(:dataset_item, { order: 2_000_000_000.1 })).to be_valid
  end

  it 'should get the created_at field populated automatically' do
    now = Time.zone.now
    soon = now + 60 # in one minute

    dataset_item = FactoryBot.create(:dataset_item)

    expect(dataset_item.created_at).to be_kind_of(ActiveSupport::TimeWithZone)
    expect(dataset_item.created_at > now).to be_truthy
    expect(dataset_item.created_at < soon).to be_truthy
  end
end
