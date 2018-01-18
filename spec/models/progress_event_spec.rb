require 'rails_helper'

RSpec.describe ProgressEvent, type: :model do

  subject { FactoryGirl.build(:progress_event) }
  it 'has a valid factory' do
    expect(FactoryGirl.create(:progress_event)).to be_valid
  end

  activities = ['viewed', 'played', 'annotated']

  it 'is invalid if activities do not belong the the set of accepted values' do
    expect(build(:progress_event, {activity: activities[0]})).to be_valid
    expect(build(:progress_event, {activity: activities[1]})).to be_valid
    expect(build(:progress_event, {activity: activities[2]})).to be_valid
    expect(build(:progress_event, {activity: 'something else'})).not_to be_valid
  end
  
end
