# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                   :integer          not null, primary key
#  deleted_at           :datetime
#  description          :text
#  image_content_type   :string
#  image_file_name      :string
#  image_file_size      :bigint
#  image_updated_at     :datetime
#  latitude             :decimal(9, 6)
#  longitude            :decimal(9, 6)
#  name                 :string           not null
#  notes                :text
#  obfuscated_latitude  :decimal(9, 6)
#  obfuscated_longitude :decimal(9, 6)
#  rails_tz             :string(255)
#  tzinfo_tz            :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  creator_id           :integer          not null
#  deleter_id           :integer
#  region_id            :integer
#  updater_id           :integer
#
# Indexes
#
#  index_sites_on_creator_id            (creator_id)
#  index_sites_on_deleter_id            (deleter_id)
#  index_sites_on_obfuscated_latitude   (obfuscated_latitude)
#  index_sites_on_obfuscated_longitude  (obfuscated_longitude)
#  index_sites_on_updater_id            (updater_id)
#
# Foreign Keys
#
#  fk_rails_...         (region_id => regions.id) ON DELETE => cascade
#  sites_creator_id_fk  (creator_id => users.id)
#  sites_deleter_id_fk  (deleter_id => users.id)
#  sites_updater_id_fk  (updater_id => users.id)
#

describe Site do
  it 'has a valid factory' do
    expect(create(:site)).to be_valid
  end

  it 'creates just one project when the factory is created' do
    site = create(:site)
    expect(site.projects.size).to eq 1
    expect(site.region.project.id).to eq(site.projects.first.id)
  end

  it 'is invalid without a name' do
    expect(build(:site, name: nil)).not_to be_valid
  end

  it 'requires a name with at least two characters' do
    s = build(:site, name: 's')
    expect(s).not_to be_valid
    expect(s).not_to be_valid
    expect(s.errors[:name].size).to eq 1
  end

  describe 'location obfuscation' do
    latitudes = [
      { -100 => false },
      { -91 => false },
      { -90 => true },
      { -89 => true },
      { 0 => true },
      { 89 => true },
      { 90 => true },
      { 91 => false },
      { 100 => false }
    ]

    longitudes = [
      { -200 => false },
      { -181 => false },
      { -180 => true },
      { -179 => true },
      { 0 => true },
      { 179 => true },
      { 180 => true },
      { 181 => false },
      { 200 => false }
    ]
    it 'obfuscates locations' do
      s = Site.new(latitude: -30.0873, longitude: 145.894)

      aggregate_failures do
        expect(s.custom_latitude).to be_within(Site::JITTER_RANGE).of(s.latitude)
        expect(s.custom_longitude).to be_within(Site::JITTER_RANGE).of(s.longitude)

        jitter_exclude_range = Site::JITTER_RANGE * 0.1
        expect(s.custom_latitude).not_to be_within(jitter_exclude_range).of(s.latitude)
        expect(s.custom_longitude).not_to be_within(jitter_exclude_range).of(s.longitude)
      end
    end

    it 'can obfuscate locations in sql' do
      s = Site.new(latitude: -30.0873, longitude: 145.894)
    end

    it 'location obfuscation is stable' do
      s1 = Site.new(latitude: -30.0873, longitude: 145.894)
      s2 = Site.new(latitude: -30.0873, longitude: 145.894)

      # tiny one digit change in longitude
      s3 = Site.new(latitude: -30.0873, longitude: 145.895)

      # tiny one digit change in latitude
      s4 = Site.new(latitude: -30.0872, longitude: 145.894)

      expect(s1.custom_latitude).to eq(s2.custom_latitude)
      expect(s1.custom_latitude).to eq(s2.custom_latitude)

      expect(s1.custom_latitude).not_to eq(s3.custom_latitude)
      expect(s1.custom_latitude).not_to eq(s3.custom_latitude)

      expect(s1.custom_latitude).not_to eq(s4.custom_latitude)
      expect(s1.custom_latitude).not_to eq(s4.custom_latitude)
    end

    it 'obfuscates lat/longs properly' do
      original_lat = -23.0
      original_lng = 127.0
      s = build(:site, :with_lat_long)

      jitter_range = Site::JITTER_RANGE
      jitter_exclude_range = Site::JITTER_RANGE * 0.1

      lat_min = Site::LATITUDE_MIN
      lat_max = Site::LATITUDE_MAX
      lng_min = Site::LONGITUDE_MIN
      lng_max = Site::LONGITUDE_MAX

      100.times {
        s.latitude = original_lat
        s.longitude = original_lng

        jit_lat = Site.add_location_jitter(s.latitude, lat_min, lat_max, s.location_jitter_seed)
        jit_lng = Site.add_location_jitter(s.longitude, lng_min, lng_max, s.location_jitter_seed)

        expect(jit_lat).to be_within(jitter_range).of(s.latitude)
        expect(jit_lat).not_to be_within(jitter_exclude_range).of(s.latitude)

        expect(jit_lng).to be_within(jitter_range).of(s.longitude)
        expect(jit_lng).not_to be_within(jitter_exclude_range).of(s.longitude)
      }
    end

    it 'returns nil for obfuscated location when inputs are nil' do
      s1 = Site.new(latitude: nil, longitude: 145.894)
      s2 = Site.new(latitude: -30.0873, longitude: nil)
      s3 = Site.new(latitude: nil, longitude: nil)

      expect([s1.custom_latitude, s2.custom_latitude, s3.custom_latitude]).to match(
        [
          nil,
          be_within(Site::JITTER_RANGE).of(-30.0873),
          nil
        ]
      )

      expect([s1.custom_longitude, s2.custom_longitude, s3.custom_longitude]).to match(
        [
          be_within(Site::JITTER_RANGE).of(145.894),
          nil,
          nil
        ]
      )
    end

    it 'latitude should be within the range [-90, 90]' do
      site = build(:site)

      latitudes.each { |value, pass|
        site.latitude = value
        if pass
          expect(site).to be_valid
        else
          expect(site).not_to be_valid
        end
      }
    end

    it 'longitudes should be within the range [-180, 180]' do
      site = build(:site)

      longitudes.each { |value, pass|
        site.longitude = value
        if pass
          expect(site).to be_valid
        else
          expect(site).not_to be_valid
        end
      }
    end
  end

  it { is_expected.to have_many(:projects).through(:projects_sites) }
  it { is_expected.to have_many(:projects_sites) }
  it { is_expected.to belong_to(:region).optional }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it 'errors on checking orphaned site if site is orphaned' do
    site = create(:site)
    site.projects = []
    expect {
      Access::Core.check_orphan_site!(site)
    }.to raise_error(CustomErrors::OrphanedSiteError)
  end

  it 'generates html for description' do
    md = "# Header\r\n [a link](https://github.com)."
    html = "<h1 id=\"header\">Header</h1>\n<p><a href=\"https://github.com\">a link</a>.</p>\n"
    site_html = create(:site, description: md)

    expect(site_html.description).to eq(md)
    expect(site_html.description_html).to eq(html)
  end

  it 'is invalid with an invalid timezone' do
    site = build(:site, tzinfo_tz: 'blah')
    expect(site).not_to be_valid
  end

  it 'errors on invalid timezone' do
    site = create(:site)
    expect(site).to be_valid

    site.tzinfo_tz = 'blah'
    expect {
      site.save!
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Tzinfo tz is not a recognized timezone ('blah')")
  end

  it 'is valid for a valid timezone' do
    expect(create(:site, tzinfo_tz: 'Australia - Brisbane')).to be_valid
  end

  it 'includes TimeZoneAttribute' do
    expect(Site.new).to be_a(TimeZoneAttribute)
  end

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image).
  #                 allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
  #                 rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }

  describe 'safe names' do
    [
      ["!aNT's fully s!ck site 1337 ;;\n../\\", 'aNTs-fully-s-ck-site-1337'],
      ['Hello - World', 'Hello-World'],
      ['!@#!#$$@!%', '']
    ].each do |name, safe_name|
      it 'has a safe_name function' do
        site = build(:site, name:)
        expect(site.safe_name).to eq(safe_name)
      end

      it 'has an arel equivalent of safe_name' do
        site = create(:site, name:)
        actual = Site.where(id: site.id).pick(Site::SAFE_NAME_AREL)

        expect(actual).to eq(safe_name)
      end
    end
  end

  it_behaves_like 'cascade deletes for', :site, {
    audio_recordings: {
      audio_events: {
        taggings: nil,
        comments: nil,
        verifications: nil
      },
      analysis_jobs_items: :audio_event_import_files,
      bookmarks: nil,
      dataset_items: {
        progress_events: nil,
        responses: nil
      },
      harvest_item: nil,
      statistics: nil
    },
    projects_sites: nil
  } do
    create_entire_hierarchy
  end
end
