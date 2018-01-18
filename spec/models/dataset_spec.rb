require 'rails_helper'

RSpec.describe Dataset, type: :model do

  subject { FactoryGirl.build(:dataset) }
  it 'has a valid factory' do
    expect(FactoryGirl.create(:dataset)).to be_valid
  end
  it 'is invalid if the name is missing' do
    expect(build(:dataset, {name: ''})).not_to be_valid
  end

end
