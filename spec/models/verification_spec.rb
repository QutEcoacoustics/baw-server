# frozen_string_literal: true

describe Verification, :andrew do
  it 'has a valid factory' do
    v = create(:verification)

    expect(v).to be_valid
  end

  it { is_expected.to belong_to(:audio_event) }
  it { is_expected.to belong_to(:tag) }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }

  it 'does not allow nil for confirmed' do
    expect(build(:verification, confirmed: nil)).not_to be_valid
  end

  it 'is not valid with an invalid confirmed value' do
    expect(build(:verification, confirmed: 'this_is_not_valid')).not_to be_valid
  end

  Verification::CONFIRMATION_ENUM.each_key do |key|
    it "is valid with confirmed value '#{key}'" do
      v = build(:verification, confirmed: key)
      expect(v).to be_valid
    end
  end

  it 'does not allow for a duplicate creator_id, audio_event_id, and tag_id combination' do
    v = create(:verification)
    expect(build(:verification, creator_id: v.creator_id, audio_event_id: v.audio_event_id,
      tag_id: v.tag_id)).not_to be_valid
  end

  it 'allows a user to have multiple verifications for different audio events and tags' do
    v = create(:verification)
    expect(build(:verification, creator_id: v.creator_id)).to be_valid
  end

  it 'allows nil for updater_id' do
    expect(build(:verification, updater_id: nil)).to be_valid
  end

  it 'allows updater_id to be set' do
    v = create(:verification)
    expect(build(:verification, updater_id: v.creator_id)).to be_valid
  end
end
