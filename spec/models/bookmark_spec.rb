# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                 :integer          not null, primary key
#  category           :string
#  description        :text
#  name               :string
#  offset_seconds     :decimal(10, 4)
#  created_at         :datetime
#  updated_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer          not null
#  updater_id         :integer
#
# Indexes
#
#  bookmarks_name_creator_id_uidx         (name,creator_id) UNIQUE
#  index_bookmarks_on_audio_recording_id  (audio_recording_id)
#  index_bookmarks_on_creator_id          (creator_id)
#  index_bookmarks_on_updater_id          (updater_id)
#
# Foreign Keys
#
#  bookmarks_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  bookmarks_creator_id_fk          (creator_id => users.id)
#  bookmarks_updater_id_fk          (updater_id => users.id)
#
describe Bookmark do
  subject { build(:bookmark) }

  it 'has a valid factory' do
    expect(create(:bookmark)).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }

  it 'is invalid without name specified' do
    b = build(:bookmark, name: nil)
    expect(b).not_to be_valid
  end

  it { is_expected.to validate_presence_of(:offset_seconds) }
  it { is_expected.to validate_numericality_of(:offset_seconds).is_greater_than_or_equal_to(0) }

  it 'is invalid without offset_seconds specified' do
    expect(build(:bookmark, offset_seconds: nil)).not_to be_valid
  end

  it 'is invalid with offset_seconds set to less than zero' do
    expect(build(:bookmark, offset_seconds: -1)).not_to be_valid
  end

  it {
    is_expected.to validate_uniqueness_of(:name).case_insensitive.scoped_to(:creator_id).with_message('should be unique per user')
  }

  it 'does not allow duplicate names for the same user (case-insensitive)' do
    user = create(:user)
    create(:bookmark, { creator: user, name: 'I love the smell of napalm in the morning.' })
    ss = build(:bookmark, { creator: user, name: 'I LOVE the smell of napalm in the morning.' })
    expect(ss).not_to be_valid
    expect(ss).not_to be_valid

    ss.name = 'I love the smell of napalm in the morning. It smells like victory.'
    ss.save
    expect(ss).to be_valid
  end

  it 'allows duplicate names for different users (case-insensitive)' do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    ss1 = create(:bookmark, { creator: user1, name: 'You talkin\' to me?' })

    ss2 = build(:bookmark, { creator: user2, name: 'You TALKIN\' to me?' })
    expect(ss2.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss2).to be_valid

    ss3 = build(:bookmark, { creator: user3, name: 'You talkin\' to me?' })
    expect(ss3.creator_id).not_to eql(ss1.creator_id), 'The same user is present for both cases, invalid test!'
    expect(ss3).to be_valid
  end

  it_behaves_like 'cascade deletes for', :bookmark, {} do
    create_entire_hierarchy
  end
end
