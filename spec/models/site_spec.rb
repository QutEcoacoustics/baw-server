require 'rails_helper'

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
    original_lat = -23.0
    original_lng = 127.0
    s = FactoryGirl.build(:site, :with_lat_long)

    jitter_range = Site::JITTER_RANGE
    jitter_exclude_range = Site::JITTER_RANGE * 0.1

    lat_min = Site::LATITUDE_MIN
    lat_max = Site::LATITUDE_MAX
    lng_min = Site::LONGITUDE_MIN
    lng_max = Site::LONGITUDE_MAX

    100.times {
      s.latitude = original_lat
      s.longitude = original_lng

      jit_lat = Site.add_location_jitter(s.latitude, lat_min, lat_max)
      jit_lng = Site.add_location_jitter(s.longitude, lng_min, lng_max)

      expect(jit_lat).to be_within(jitter_range).of(s.latitude)
      expect(jit_lat).to_not be_within(jitter_exclude_range).of(s.latitude)

      expect(jit_lng).to be_within(jitter_range).of(s.longitude)
      expect(jit_lng).to_not be_within(jitter_exclude_range).of(s.longitude)
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
  it { is_expected.to have_and_belong_to_many :projects }

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it 'should error on checking orphaned site if site is orphaned' do
    site = FactoryGirl.create(:site, projects: [])
    expect {
      Access::Core.check_orphan_site!(site)
    }.to raise_error(CustomErrors::OrphanedSiteError)
  end

  it 'generates html for description' do
    md = "# Header\r\n [a link](https://github.com)."
    html = "<h1>Header</h1>\n<p><a href=\"https://github.com\">a link</a>.</p>\n"
    projectHtml = FactoryGirl.create(:site, description: md)

    expect(projectHtml.description).to eq(md)
    expect(projectHtml.description_html).to eq(html)

  end

  it 'should error on invalid timezone' do
    expect {
      FactoryGirl.create(:site, tzinfo_tz: 'blah')
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Tzinfo tz is not a recognised timezone ('blah')")
  end

  it 'should be valid for a valid timezone' do
    expect(FactoryGirl.create(:site, tzinfo_tz: 'Australia - Brisbane')).to be_valid
  end

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image).
  #                 allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
  #                 rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }
end