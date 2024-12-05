# frozen_string_literal: true

# == Schema Information
#
# Table name: datasets
#
#  id          :integer          not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
RSpec.describe Dataset, type: :model do
  subject { build(:dataset) }

  it 'has a valid factory' do
    expect(create(:dataset)).to be_valid
  end

  it 'is invalid if the name is missing' do
    expect(build(:dataset, { name: '' })).not_to be_valid
  end

  it 'is invalid if missing creator id' do
    expect(build(:dataset, { creator_id: nil })).not_to be_valid
  end

  it 'has the created_at and updated_at field populated automatically' do
    now = Time.zone.now
    soon = now + 60 # in one minute

    dataset = create(:dataset)

    expect(dataset.created_at).to be_a(ActiveSupport::TimeWithZone)
    expect(dataset.created_at > now).to be_truthy
    expect(dataset.created_at < soon).to be_truthy

    dataset.description = 'Testing updating dataset description'
    dataset.save!

    expect(dataset.updated_at).to be_a(ActiveSupport::TimeWithZone)
    expect(dataset.updated_at > dataset.created_at).to be_truthy
    expect(dataset.updated_at < soon).to be_truthy
  end

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }

  it_behaves_like 'cascade deletes for', :dataset, {
    dataset_items: {
      progress_events: nil,
      responses: nil
    },
    study: {
      questions_studies: nil,
      responses: nil
    }
  } do
    create_entire_hierarchy
  end
end
