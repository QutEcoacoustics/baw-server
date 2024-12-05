# frozen_string_literal: true

# == Schema Information
#
# Table name: responses
#
#  id              :integer          not null, primary key
#  data            :text
#  created_at      :datetime
#  creator_id      :integer
#  dataset_item_id :integer
#  question_id     :integer
#  study_id        :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_item_id => dataset_items.id) ON DELETE => cascade
#  fk_rails_...  (question_id => questions.id)
#  fk_rails_...  (study_id => studies.id)
#
RSpec.describe Response do
  let(:dataset_item) {
    create(:dataset_item)
  }
  let(:study) {
    create(:study, dataset_id: dataset_item.dataset_id)
  }
  let(:question) {
    create(:question, studies: [study])
  }

  it 'has a valid factory' do
    expect(create(:response, question:, study:, dataset_item:)).to be_valid
    expect(create(:response, question_id: question.id, study_id: study.id,
      dataset_item_id: dataset_item.id)).to be_valid
  end

  it 'created_at should be set by rails' do
    item = create(:response, question:, study:, dataset_item:)
    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true
    item.reload
    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true
  end

  describe 'associations' do
    it { is_expected.to belong_to(:question) }
    it { is_expected.to belong_to(:study) }
    it { is_expected.to belong_to(:dataset_item) }
    it { is_expected.to belong_to(:creator) }
  end

  describe 'validations' do
    it 'cannot be created without a dataset_item' do
      expect {
        create(:response, question:, study:, dataset_item: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'cannot be created without a question' do
      expect {
        create(:response, question: nil, study:, dataset_item:)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'cannot be created without a study' do
      expect {
        create(:response, question:, study: nil, dataset_item:)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not be associated with a nonexistent dataset item' do
      expect {
        create(:response, question:, study:, dataset_item_id: 12_345)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not be associated with a nonexistent question' do
      expect {
        create(:response, question:, study_id: 12_345, dataset_item:)
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not be associated with a nonexistent study' do
      expect {
        create(:response, question_id: 12_345, study:, dataset_item:)
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'does not allow unrelated parent question and parent study' do
      other_study = create(:study)
      expect {
        create(:response, question_id: question.id, study_id: other_study.id, dataset_item:)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
