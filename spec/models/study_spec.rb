require 'rails_helper'

RSpec.describe Study, type: :model do

  let(:dataset) {
    FactoryGirl.create(:dataset)
  }

  it 'has a valid factory' do
    expect(create(:study, dataset: dataset)).to be_valid
  end

  it 'created_at should be set by rails' do
    item = create(:study, dataset: dataset)
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
    item.reload
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
  end

  describe 'associations' do
    it { is_expected.to have_and_belong_to_many(:questions) }
    it { is_expected.to have_many(:responses) }
    it { is_expected.to belong_to(:dataset) }
    it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
    it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  end

  describe 'validations' do

    it { is_expected.to validate_presence_of(:dataset) }

    it 'cannot be created without a dataset' do
      expect {
        create(:study, dataset: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it { is_expected.to validate_presence_of(:creator) }

    it 'can not create a study associated with a nonexistent dataset' do
      expect {
        create(:study, dataset_id: 12345)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not create a study with a nonexistent question' do
      expect {
        create(:study, question_ids: [12345])
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

  end

end
