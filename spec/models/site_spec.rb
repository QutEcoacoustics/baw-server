require 'spec_helper'

latitudes = [
    {-100 => false},
    {-91 => false},
    {-90 => true},
    {-89 => true},
    {0 => true},
    {89 => true},
    {90 => true},
    {91 => false},
    {100 => false}
]

longitudes = [
    {-200 => false},
    {-181 => false},
    {-180 => true},
    {-179 => true},
    {0 => true},
    {179 => true},
    {180 => true},
    {181 => false},
    {200 => false}
]

describe Site do
  it 'has a valid factory' do
    FactoryGirl.create(:site).should be_valid
  end
  it 'is invalid without an name' do
    FactoryGirl.build(:site, :name => nil).should_not be_valid
  end
  it 'requires a name with at least two characters' do
    s = FactoryGirl.build(:site, :name => 's')
    s.should_not be_valid
    s.should have(1).error_on(:name)
  end
  it 'latitude should be within the range [-90, 90]' do
    site = FactoryGirl.build(:site)

    latitudes.each { |value, pass|
      site.latitude = value
      if pass then
        site.should be_valid
      else
        site.should_not be_valid
      end
    }
  end
  it 'longitudes should be within the range [-180, 180]' do
    site = FactoryGirl.build(:site)

    longitudes.each { |value, pass|
      site.longitude = value
      if pass then
        site.should be_valid
      else
        site.should_not be_valid
      end
    }
  end
  it {should have_and_belong_to_many :projects}
end