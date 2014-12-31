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

describe Site, :type => :model do
  it 'has a valid factory' do
    expect(FactoryGirl.create(:site)).to be_valid
  end
  it 'is invalid without a name' do
    expect(FactoryGirl.build(:site, :name => nil)).not_to be_valid
  end
  it 'requires a name with at least two characters' do
    s = FactoryGirl.build(:site, :name => 's')
    expect(s).not_to be_valid
    expect(s.valid?).to be_falsey
    expect(s.errors[:name].size).to eq(1)
  end

  it 'should obfuscate lat/longs properly' do

    10.times {
      s = FactoryGirl.build(:site_with_lat_long)
      expect(Site.add_location_jitter(s.longitude, Site::LONGITUDE_MIN, Site::LONGITUDE_MAX)).to be_within(Site::JITTER_RANGE).of(s.longitude)
      expect(Site.add_location_jitter(s.latitude, Site::LATITUDE_MIN, Site::LATITUDE_MAX)).to be_within(Site::JITTER_RANGE).of(s.latitude)
    }
  end

  it 'latitude should be within the range [-90, 90]' do
    site = FactoryGirl.build(:site)

    latitudes.each { |value, pass|
      site.latitude = value
      if pass then
        expect(site).to be_valid
      else
        expect(site).not_to be_valid
      end
    }
  end
  it 'longitudes should be within the range [-180, 180]' do
    site = FactoryGirl.build(:site)

    longitudes.each { |value, pass|
      site.longitude = value
      if pass then
        expect(site).to be_valid
      else
        expect(site).not_to be_valid
      end
    }
  end
  it {is_expected.to have_and_belong_to_many :projects}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image).
  #                 allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
  #                 rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }
end