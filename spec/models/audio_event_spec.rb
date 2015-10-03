require 'rails_helper'

describe AudioEvent, :type => :model do
  subject { FactoryGirl.build(:audio_event) }
  it 'has a valid factory' do
    expect(FactoryGirl.create(:audio_event)).to be_valid
  end
  it 'can have a blank end time' do
    ae = FactoryGirl.build(:audio_event, :end_time_seconds => nil)
    expect(ae).to be_valid
  end
  it 'can have a blank high frequency' do
    expect(FactoryGirl.build(:audio_event, :high_frequency_hertz => nil)).to be_valid
  end
  it 'can have a blank end time and  a blank high frequency' do
    expect(FactoryGirl.build(:audio_event, {:end_time_seconds => nil, :high_frequency_hertz => nil})).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { is_expected.to have_many(:tags) }
  it { is_expected.to accept_nested_attributes_for(:tags) }

  it { is_expected.to validate_inclusion_of(:is_reference).in_array([true, false]) }

  it { is_expected.to validate_presence_of(:start_time_seconds) }
  it { is_expected.to validate_numericality_of(:start_time_seconds).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:end_time_seconds).is_greater_than_or_equal_to(0).allow_nil }

  it { is_expected.to validate_presence_of(:low_frequency_hertz) }
  it { is_expected.to validate_numericality_of(:low_frequency_hertz).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:high_frequency_hertz).is_greater_than_or_equal_to(0).allow_nil }

  it 'is invalid if the end time is less than the start time' do
    expect(build(:audio_event, {start_time_seconds: 100.320, end_time_seconds: 10.360})).not_to be_valid
  end

  it 'is invalid if the end frequency is less then the low frequency' do
    expect(build(:audio_event, {low_frequency_hertz: 1000, high_frequency_hertz: 100})).not_to be_valid
  end

end