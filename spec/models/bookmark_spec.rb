require 'spec_helper'

describe Bookmark, :type => :model do
  it 'has a valid factory' do
    expect(create(:bookmark)).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }

  it { is_expected.to validate_presence_of(:audio_recording_id) }

  it 'is invalid without name specified' do
    b = build(:bookmark, name: nil)
    expect(b).not_to be_valid
  end

  it { is_expected.to validate_presence_of(:offset_seconds) }
  it { is_expected.to validate_numericality_of(:offset_seconds) }
  it 'is invalid without offset_seconds specified' do
    expect(build(:bookmark, offset_seconds: nil)).not_to be_valid
  end
  it 'is invalid with offset_seconds set to less than zero' do
    expect(build(:bookmark, offset_seconds: -1)).not_to be_valid
  end

  it 'should not allow duplicate names for the same user (case-insensitive)' do
    user = create(:user)
    create(:bookmark, {creator: user, name: 'I love the smell of napalm in the morning.'})
    ss = build(:bookmark, {creator: user, name: 'I LOVE the smell of napalm in the morning.'})
    expect(ss).not_to be_valid
    expect(ss.valid?).to be_falsey
    expect(ss.errors[:name].size).to eq(1)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    expect(ss).to be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    ss1 = create(:bookmark, {creator: user1, name: 'You talkin\' to me?'})

    ss2 = build(:bookmark, {creator: user2, name: 'You TALKIN\' to me?'})
    expect(ss2.creator_id).not_to eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    expect(ss2).to be_valid

    ss3 = build(:bookmark, {creator: user3, name: 'You talkin\' to me?'})
    expect(ss3.creator_id).not_to eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    expect(ss3).to be_valid
  end

  it 'should not allow duplicate names for the same user (case-insensitive)' do
    user = create(:user)
    create(:bookmark, {creator: user, name: 'I love the smell of napalm in the morning.'})
    ss = build(:bookmark, {creator: user, name: 'I LOVE the smell of napalm in the morning.'})
    expect(ss).not_to be_valid
    expect(ss.valid?).to be_falsey
    expect(ss.errors[:name].size).to eq(1)

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    expect(ss).to be_valid

  end

  it 'should allow duplicate names for different users (case-insensitive)' do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    ss1 = create(:bookmark, {creator: user1, name: 'You talkin\' to me?'})

    ss2 = build(:bookmark, {creator: user2, name: 'You TALKIN\' to me?'})
    expect(ss2.creator_id).not_to eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    expect(ss2).to be_valid

    ss3 = build(:bookmark, {creator: user3, name: 'You talkin\' to me?'})
    expect(ss3.creator_id).not_to eql(ss1.creator_id), "The same user is present for both cases, invalid test!"
    expect(ss3).to be_valid
  end

end