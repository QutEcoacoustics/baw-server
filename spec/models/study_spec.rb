# frozen_string_literal: true

# == Schema Information
#
# Table name: studies
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :integer
#  dataset_id :integer
#  updater_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#  fk_rails_...  (updater_id => users.id)
#
RSpec.describe Study do
  let(:dataset) {
    create(:dataset)
  }

  it 'has a valid factory' do
    expect(create(:study, dataset:)).to be_valid
  end

  it 'created_at should be set by rails' do
    item = create(:study, dataset:)
    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true
    item.reload
    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true
  end

  describe 'associations' do
    it { is_expected.to have_many(:questions).through(:questions_studies) }
    it { is_expected.to have_many(:questions_studies) }
    it { is_expected.to have_many(:responses) }
    it { is_expected.to belong_to(:dataset) }
    it { is_expected.to belong_to(:updater).optional }
    it { is_expected.to belong_to(:creator) }
  end

  describe 'validations' do
    it 'cannot be created without a dataset' do
      expect {
        create(:study, dataset: nil)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not create a study associated with a nonexistent dataset' do
      expect {
        create(:study, dataset_id: 12_345)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can not create a study with a nonexistent question' do
      expect {
        create(:study, question_ids: [12_345])
        # not sure why the error is different for the two associations
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
