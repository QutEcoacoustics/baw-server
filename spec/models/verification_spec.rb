# frozen_string_literal: true

# == Schema Information
#
# Table name: verifications
#
#  id             :bigint           not null, primary key
#  confirmed      :enum             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  audio_event_id :bigint           not null
#  creator_id     :integer          not null
#  tag_id         :bigint           not null
#  updater_id     :integer
#
# Indexes
#
#  idx_on_audio_event_id_tag_id_creator_id_f944f25f20  (audio_event_id,tag_id,creator_id) UNIQUE
#  index_verifications_on_audio_event_id               (audio_event_id)
#  index_verifications_on_tag_id                       (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_event_id => audio_events.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (tag_id => tags.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
describe Verification do
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
    it "is valid with confirmed value `#{key}`" do
      v = build(:verification, confirmed: key)
      expect(v).to be_valid
    end
  end

  it 'allows a user to have multiple verifications for different audio events and tags' do
    v = create(:verification)
    expect(build(:verification, creator_id: v.creator_id)).to be_valid
  end
end
