require 'spec_helper'

describe Bookmark do
  it 'has a valid factory' do
    create(:bookmark).should be_valid
  end

  it { should belong_to(:audio_recording) }
  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }

  it { should validate_presence_of(:audio_recording_id) }

  it 'is invalid without name specified' do
    b = build(:bookmark, name: nil)
    b.should_not be_valid
  end

  it { should validate_presence_of(:offset_seconds) }
  it { should validate_numericality_of(:offset_seconds) }
  it 'is invalid without offset_seconds specified' do
    build(:bookmark, offset_seconds: nil).should_not be_valid
  end
  it 'is invalid with offset_seconds set to less than zero' do
    build(:bookmark, offset_seconds: -1).should_not be_valid
  end

  it 'should not allow duplicate names for the same user (case-insensitive)' do
    create(:bookmark, {creator_id: 3, name: 'I love the smell of napalm in the morning.'})
    ss = build(:bookmark, {creator_id: 3, name: 'I LOVE the smell of napalm in the morning.'})
    ss.should_not be_valid
    ss.should have(1).error_on(:name)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    ss.should be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    ss1 = create(:bookmark, {creator_id: 3, name: 'You talkin\' to me?'})

    ss2 = build(:bookmark, {creator_id: 1, name: 'You TALKIN\' to me?'})
    ss2.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss2.should be_valid

    ss3 = build(:bookmark, {creator_id: 2, name: 'You talkin\' to me?'})
    ss3.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss3.should be_valid
  end

  it 'should not allow duplicate names for the same user (case-insensitive)' do
    create(:bookmark, {creator_id: 3, name: 'I love the smell of napalm in the morning.'})
    ss = build(:bookmark, {creator_id: 3, name: 'I LOVE the smell of napalm in the morning.'})
    ss.should_not be_valid
    ss.should have(1).error_on(:name)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    ss.should be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    ss1 = create(:bookmark, {creator_id: 3, name: 'You talkin\' to me?'})

    ss2 = build(:bookmark, {creator_id: 1, name: 'You TALKIN\' to me?'})
    ss2.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss2.should be_valid

    ss3 = build(:bookmark, {creator_id: 2, name: 'You talkin\' to me?'})
    ss3.creator_id.should_not eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    ss3.should be_valid
  end

end