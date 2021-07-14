# frozen_string_literal: true

# == Schema Information
#
# Table name: regions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  name        :string
#  notes       :jsonb
#  created_at  :datetime
#  updated_at  :datetime
#  creator_id  :integer
#  deleter_id  :integer
#  project_id  :integer          not null
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
describe Region, type: :model do
  it 'has a valid factory' do
    expect(FactoryBot.create(:region)).to be_valid
  end
  it 'is invalid without a name' do
    expect(FactoryBot.build(:region, name: nil)).not_to be_valid
  end
  it 'requires a name with at least two characters' do
    s = FactoryBot.build(:region, name: 's')
    expect(s).not_to be_valid
    expect(s.valid?).to be_falsey
    expect(s.errors[:name].size).to eq(1)
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:sites) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id).optional }
end
