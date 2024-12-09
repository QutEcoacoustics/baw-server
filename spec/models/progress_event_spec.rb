# frozen_string_literal: true

# == Schema Information
#
# Table name: progress_events
#
#  id              :integer          not null, primary key
#  activity        :string
#  created_at      :datetime
#  creator_id      :integer
#  dataset_item_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_item_id => dataset_items.id) ON DELETE => cascade
#
RSpec.describe ProgressEvent, type: :model do
  subject { FactoryBot.build(:progress_event) }
  it 'has a valid factory' do
    expect(FactoryBot.create(:progress_event)).to be_valid
  end

  activities = ['viewed', 'played', 'annotated']

  it 'is invalid if activities do not belong the the set of accepted values' do
    expect(build(:progress_event, { activity: activities[0] })).to be_valid
    expect(build(:progress_event, { activity: activities[1] })).to be_valid
    expect(build(:progress_event, { activity: activities[2] })).to be_valid
    expect(build(:progress_event, { activity: 'something else' })).not_to be_valid
  end

  it 'is invalid if missing creator_id' do
    expect(build(:progress_event, { creator_id: nil })).not_to be_valid
  end

  it 'is invalid if missing dataset_item_id' do
    expect(build(:progress_event, { dataset_item_id: nil })).not_to be_valid
  end

  it 'should get the created_at field populated automatically' do
    now = Time.zone.now
    soon = now + 60 # in one minute

    progress_event = FactoryBot.create(:progress_event)

    expect(progress_event.created_at).to be_kind_of(ActiveSupport::TimeWithZone)
    expect(progress_event.created_at > now).to be_truthy
    expect(progress_event.created_at < soon).to be_truthy
  end
end
