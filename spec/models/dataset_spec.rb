# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dataset, type: :model do
  subject { FactoryBot.build(:dataset) }

  it 'has a valid factory' do
    expect(FactoryBot.create(:dataset)).to be_valid
  end

  it 'is invalid if the name is missing' do
    expect(build(:dataset, { name: '' })).not_to be_valid
  end

  it 'is invalid if missing creator id' do
    expect(build(:dataset, { creator_id: nil })).not_to be_valid
  end

  it 'should have the created_at and updated_at field populated automatically' do
    now = Time.zone.now
    soon = now + 60 # in one minute

    dataset = FactoryBot.create(:dataset)

    expect(dataset.created_at).to be_kind_of(ActiveSupport::TimeWithZone)
    expect(dataset.created_at > now).to be_truthy
    expect(dataset.created_at < soon).to be_truthy

    dataset.description = 'Testing updating dataset description'
    dataset.save!

    expect(dataset.updated_at).to be_kind_of(ActiveSupport::TimeWithZone)
    expect(dataset.updated_at > dataset.created_at).to be_truthy
    expect(dataset.updated_at < soon).to be_truthy
  end

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
end
