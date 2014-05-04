require 'spec_helper'

describe AudioEvent do
  it 'has a valid factory' do
    FactoryGirl.create(:audio_event).should be_valid
  end
  it 'can have a blank end time' do
    ae = FactoryGirl.build(:audio_event, :end_time_seconds => nil)
    ae.should be_valid
  end
  it 'can have a blank high frequency' do
    FactoryGirl.build(:audio_event, :high_frequency_hertz => nil).should be_valid
  end
  it 'can have a blank end time and  a blank high frequency' do
    FactoryGirl.build(:audio_event, {:end_time_seconds => nil, :high_frequency_hertz => nil}).should be_valid
  end
  it { should belong_to(:audio_recording)}
  it { should have_many(:tags)}

  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }
  it { should belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { should validate_presence_of(:start_time_seconds)}
  it { should validate_numericality_of(:start_time_seconds) }
  it 'is invalid without a start time' do
    build(:audio_event, start_time_seconds: nil).should_not be_valid
  end
  it 'is invalid with a start time less than zero' do
    build(:audio_event, start_time_seconds: -1).should_not be_valid
  end
  it 'is invalid if the end time is less than the start time' do
    build(:audio_event, {start_time_seconds: 100.320, end_time_seconds: 10.360}).should_not be_valid
  end
  it { should validate_numericality_of(:end_time_seconds) }
  it { should validate_presence_of(:low_frequency_hertz)}
  it { should validate_numericality_of(:low_frequency_hertz) }
  it 'is invalid without a low frequency' do
    build(:audio_event, low_frequency_hertz: nil).should_not be_valid
  end
  it 'is invalid with a low frequency less than zero' do
    build(:audio_event, low_frequency_hertz: -1).should_not be_valid
  end
  it 'is invalid if the end frequency is less then the low frequency' do
    build(:audio_event, {low_frequency_hertz: 1000, high_frequency_hertz: 100}).should_not be_valid
  end
  it { should validate_numericality_of(:high_frequency_hertz) }
  it 'is invalid if is_reference is not specified' do
    build(:audio_event, is_reference:nil).should_not be_valid
  end

end