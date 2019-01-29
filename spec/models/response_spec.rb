require 'rails_helper'

RSpec.describe Response, type: :model do

  let(:dataset_item) {
    FactoryGirl.create(:dataset_item)
  }
  let(:study) {
    FactoryGirl.create(:study, dataset_id: dataset_item.dataset_id)
  }
  let(:question) {
    FactoryGirl.create(:question, studies: [study])
  }

  it 'has a valid factory' do
    expect(create(:response, question: question, study: study, dataset_item: dataset_item)).to be_valid
    expect(create(:response, question_id: question.id, study_id: study.id, dataset_item_id: dataset_item.id)).to be_valid
  end

  it 'created_at should be set by rails' do
    item = create(:response, question: question, study: study, dataset_item: dataset_item)
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
    item.reload
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
  end

  describe 'associations' do
    it { is_expected.to belong_to(:question) }
    it { is_expected.to belong_to(:study) }
    it { is_expected.to belong_to(:dataset_item) }
    it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  end

  describe 'validations' do

    it {
      is_expected.to validate_presence_of(:dataset_item)
    }
    it 'cannot be created without a dataset_item' do
      expect {
        create(:response, question: question, study: study, dataset_item: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it { is_expected.to validate_presence_of(:question) }
    it 'cannot be created without a question' do
      expect {
        create(:response, question: nil, study: study, dataset_item: dataset_item)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it { is_expected.to validate_presence_of(:study) }
    it 'cannot be created without a study' do
      expect {
        create(:response, question: question, study: nil, dataset_item: dataset_item)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it { is_expected.to validate_presence_of(:creator) }

    it 'can not be associated with a nonexistent dataset item' do
      expect {
        create(:response, question: question, study: study, dataset_item_id: 12345)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not be associated with a nonexistent question' do
      expect {
        create(:response, question: question, study_id: 12345, dataset_item: dataset_item)
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not be associated with a nonexistent study' do
      expect {
        create(:response, question_id: 12345, study: study, dataset_item: dataset_item)
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'does not allow unrelated parent question and parent study'  do
      other_study = create(:study)
      expect {
        create(:response, question_id: question.id, study_id: other_study.id, dataset_item: dataset_item)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

  end

end
