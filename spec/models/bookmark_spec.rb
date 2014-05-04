require 'spec_helper'

describe Bookmark do
  it 'has a valid factory' do
    create(:bookmark).should be_valid
  end

  it { should belong_to(:audio_recording)}
  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }

  it { should validate_presence_of(:audio_recording_id)}

  it 'is valid without name specified' do
    build(:bookmark, name: nil).should be_valid
  end

  it { should validate_presence_of(:offset_seconds)}
  it { should validate_numericality_of(:offset_seconds) }
  it 'is invalid without offset_seconds specified' do
    build(:bookmark, offset_seconds: nil).should_not be_valid
  end
  it 'is invalid with offset_seconds set to less than zero' do
    build(:bookmark, offset_seconds: -1).should_not be_valid
  end
end