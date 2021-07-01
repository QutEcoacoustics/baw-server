# frozen_string_literal: true

# == Schema Information
#
# Table name: questions
#
#  id         :integer          not null, primary key
#  data       :text
#  text       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :integer
#  updater_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
RSpec.describe Question, type: :model do
  let(:study) {
    FactoryBot.create(:study)
  }

  it 'has a valid factory' do
    expect(create(:question, studies: [study])).to be_valid
  end

  it 'created_at should be set by rails' do
    item = create(:question, studies: [study])
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
    item.reload
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
  end

  describe 'associations' do
    it { is_expected.to have_and_belong_to_many(:studies) }
    it { is_expected.to have_many(:responses) }
    it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
    it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:studies) }
    it 'cannot be created with no studies' do
      expect {
        create(:question, studies: [])
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
    it { is_expected.to validate_presence_of(:creator) }

    it 'can not create a question associated with a nonexistent study' do
      expect {
        # array with both an existing and nonexistent study
        create(:question, study_ids: [study.id, 12_345])
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
