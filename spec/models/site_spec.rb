# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                                                                                                    :integer          not null, primary key
#  custom_obfuscated_location(True if the obfuscated location was set by the user or false if generated) :boolean          default(FALSE), not null
#  deleted_at                                                                                            :datetime
#  description                                                                                           :text
#  image_content_type                                                                                    :string
#  image_file_name                                                                                       :string
#  image_file_size                                                                                       :bigint
#  image_updated_at                                                                                      :datetime
#  latitude                                                                                              :decimal(9, 6)
#  longitude                                                                                             :decimal(9, 6)
#  name                                                                                                  :string           not null
#  notes                                                                                                 :text
#  obfuscated_latitude                                                                                   :decimal(9, 6)
#  obfuscated_longitude                                                                                  :decimal(9, 6)
#  rails_tz                                                                                              :string(255)
#  tzinfo_tz                                                                                             :string(255)
#  created_at                                                                                            :datetime
#  updated_at                                                                                            :datetime
#  creator_id                                                                                            :integer          not null
#  deleter_id                                                                                            :integer
#  region_id                                                                                             :integer
#  updater_id                                                                                            :integer
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

  describe '#public_site?' do
    let(:site) { create(:site) }
    let(:project) { site.projects.first }

    it 'is false when permissions are user-specific' do
      expect(site).not_to be_public_site
    end

    it 'is true when any project allows anonymous access' do
      create(:read_anon_permission, creator: project.creator, project:)

      expect(site).to be_public_site
    end

    it 'is true when any project allows logged-in access' do
      create(:read_logged_in_permission, creator: project.creator, project:)

      expect(site).to be_public_site
    end
  end

  describe '#public_latitude and #public_longitude' do
    let(:site) { create(:site, :with_lat_long) }

    it 'returns obfuscated coordinates when there is no user' do
      expect(site.public_latitude).to eq(site.obfuscated_latitude)
      expect(site.public_longitude).to eq(site.obfuscated_longitude)
    end

    it 'returns real coordinates when user override has permission' do
      expect(site.public_latitude(user: site.projects.first.creator)).to eq(site.latitude)
      expect(site.public_longitude(user: site.projects.first.creator)).to eq(site.longitude)
    end

    it 'returns obfuscated coordinates when user override does not have permission' do
      user = create(:user)
      expect(site.public_latitude(user:)).to eq(site.obfuscated_latitude)
      expect(site.public_longitude(user:)).to eq(site.obfuscated_longitude)
    end

    it 'returns real coordinates when should_obfuscate is false' do
      expect(site.public_latitude(should_obfuscate: false)).to eq(site.latitude)
      expect(site.public_longitude(should_obfuscate: false)).to eq(site.longitude)
    end
  end

  describe 'coordinate uncertainty' do
    # rubocop:disable Layout/LineLength
    # Cases cover the product of the following conditions, not including invalid cases:
    #  - coordinates provided or not (latitude/longitude.present?)
    #  - uncertainty provided or not (measurement_uncertainty_provided?)
    #  - obfuscated or not (location_obfuscated)
    #  - custom obfuscation or not (custom_obfuscated_location)
    #  - nil obfuscated coordinates or not (obfuscated_latitude/longitude.nil?)
    a = 30
    b = 666
    c = 1000
    d = 367.35435
    assumed = "coordinates have an assumed measurement uncertainty of #{a} meters"
    provided = "coordinates have a measurement uncertainty of #{b} meters"
    default = "coordinates have an obfuscation uncertainty of #{d} meters"
    custom = "coordinates have an obfuscation uncertainty of #{c} meters"
    hidden = 'coordinates are intentionally hidden'

    cases =
      # coordinates_provided, uncertainty_provided, obfuscated, custom_obfuscation, nil_obfuscated_coordinates, uncertainty, tag_coordinates_obfuscated, measurement_text, obfuscation_text
      [
        [true,  false, false, true,  false, a,     false, assumed,  nil],
        [true,  true,  false, true,  false, b,     false, provided, nil],
        [true,  false, true,  true,  false, a + c, true,  assumed,  custom],
        [true,  true,  true,  true,  false, b + c, true,  provided, custom],
        [true,  false, false, false, false, a,     false, assumed,  nil],
        [false, false, false, false, false, nil,   nil,   nil,      nil],
        [true,  true,  false, false, false, b,     false, provided, nil],
        [true,  false, true,  false, false, a + d, true,  assumed,  default],
        [true,  true,  true,  false, false, b + d, true,  provided, default],
        [true,  false, false, true,  true,  a,     false, assumed,  nil],
        [true,  true,  false, true,  true,  b,     false, provided, nil],
        [true,  false, true,  true,  true,  nil,   true,  hidden,   hidden],
        [true,  true,  true,  true,  true,  nil,   true,  hidden,   hidden]
      ]

    cases.each_with_index do |single_case, index|
      it "resolves uncertainty values correctly — Case: #{index}" do
        coordinates_provided, uncertainty_provided, obfuscated,
        custom_obfuscation, nil_obfuscated_coordinates, uncertainty,
        coordinates_obfuscated_tag, measurement_text,
        obfuscated_text = single_case

        latitude, longitude = coordinates_provided ? [-27, 152] : [nil, nil]

        # When custom_obfuscated_location is false, site has default obfuscation.
        # When custom_obfuscated_location is true, site has nil obfuscated coordinates by default (which means 'intentionally hidden by user').
        site_new = create(:site, latitude:, longitude:, custom_obfuscated_location: custom_obfuscation)

        # When custom_obfuscated_location is true and nil_obfuscated_coordinates: false, this site was obfuscated by the user (e.g. a 1000m buffer).
        if custom_obfuscation && (nil_obfuscated_coordinates == false)
          site_new.obfuscated_latitude = -27.0001
          site_new.obfuscated_longitude = 152.0001
        end

        # Simulate a provided measurement uncertainty since we don't have a DB field for it.
        allow(site_new).to receive(:measurement_uncertainty_meters).and_return(uncertainty_provided ? 666 : nil)
        expect(site_new.measurement_uncertainty_provided?).to eq(uncertainty_provided)

        # TODO: remove when closed https://github.com/QutEcoacoustics/baw-server/issues/1025.
        # Until then, override the relevant cases to expect the interim behaviour.
        if obfuscated && custom_obfuscation && !nil_obfuscated_coordinates
          uncertainty = nil
          obfuscated_text = 'coordinates have an unknown obfuscation uncertainty'
        end

        expect(site_new.total_coordinate_uncertainty_meters(should_obfuscate: obfuscated)).to uncertainty.nil? ? eq(uncertainty) : be_within(2).of(uncertainty)
        expect(site_new.coordinates_provided? ? site_new.location_obfuscated(user: nil, should_obfuscate: obfuscated) : nil).to eq(coordinates_obfuscated_tag)
        expect(site_new.measurement_uncertainty_text(user: nil, should_obfuscate: obfuscated)).to eq(measurement_text)
        expect(site_new.obfuscation_uncertainty_text(user: nil, should_obfuscate: obfuscated)).to eq(obfuscated_text)
      end
    end
    # rubocop:enable Layout/LineLength
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
      s.valid? # trigger before_validation callback

      aggregate_failures do
        expect(s.obfuscated_latitude).to be_within(Site::JITTER_RANGE).of(s.latitude)
        expect(s.obfuscated_longitude).to be_within(Site::JITTER_RANGE).of(s.longitude)

        jitter_exclude_range = Site::JITTER_EXCLUSION_RANGE
        expect(s.obfuscated_latitude).not_to be_within(jitter_exclude_range).of(s.latitude)
        expect(s.obfuscated_longitude).not_to be_within(jitter_exclude_range).of(s.longitude)
      end
    end

    it 'location obfuscation is stable' do
      s1 = Site.new(latitude: -30.0873, longitude: 145.894, name: 'abc')
      s2 = Site.new(latitude: -30.0873, longitude: 145.894, name: 'abc')

      # tiny one digit change in longitude
      s3 = Site.new(latitude: -30.0873, longitude: 145.895, name: 'abc')
      # tiny one digit change in latitude
      s4 = Site.new(latitude: -30.0872, longitude: 145.894, name: 'abc')

      [s1, s2, s3, s4].each(&:valid?) # trigger before_validation callback

      expect(s1.obfuscated_latitude).to eq(s2.obfuscated_latitude)
      expect(s1.obfuscated_longitude).to eq(s2.obfuscated_longitude)

      expect(s1.obfuscated_latitude).not_to eq(s3.obfuscated_latitude)
      expect(s1.obfuscated_longitude).not_to eq(s3.obfuscated_longitude)

      expect(s1.obfuscated_latitude).not_to eq(s4.obfuscated_latitude)
      expect(s1.obfuscated_longitude).not_to eq(s4.obfuscated_longitude)
    end

    it 'obfuscates lat/longs properly' do
      original_lat = -23.0
      original_lng = 127.0
      s = build(:site, :with_lat_long)

      jitter_range = Site::JITTER_RANGE
      jitter_exclude_range = Site::JITTER_EXCLUSION_RANGE

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

      [s1, s2, s3].each(&:valid?) # trigger before_validation callback

      expect([s1.obfuscated_latitude, s2.obfuscated_latitude, s3.obfuscated_latitude]).to match(
        [
          nil,
          be_within(Site::JITTER_RANGE).of(-30.0873),
          nil
        ]
      )

      expect([s1.obfuscated_longitude, s2.obfuscated_longitude, s3.obfuscated_longitude]).to match(
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

    describe 'auto-generated obfuscated coordinates' do
      it 'generates obfuscated coordinates on create when coordinates are present' do
        site = create(:site, :with_lat_long)

        expect(site.obfuscated_latitude).to be_present
        expect(site.obfuscated_longitude).to be_present
        expect(site.custom_obfuscated_location).to be false
        expect(site.obfuscated_latitude).to be_within(Site::JITTER_RANGE).of(site.latitude)
        expect(site.obfuscated_longitude).to be_within(Site::JITTER_RANGE).of(site.longitude)
      end

      it 'does not generate obfuscated coordinates on create when coordinates are nil' do
        site = create(:site, latitude: nil, longitude: nil)

        expect(site.obfuscated_latitude).to be_nil
        expect(site.obfuscated_longitude).to be_nil
      end

      it 'updates obfuscated coordinates when latitude changes and generated flag is true' do
        site = create(:site, :with_lat_long)
        original_obfuscated_lat = site.obfuscated_latitude

        site.update!(latitude: site.latitude - site.latitude)

        expect(site.obfuscated_latitude).not_to eq(original_obfuscated_lat)
        expect(site.obfuscated_latitude).to be_within(Site::JITTER_RANGE).of(site.latitude)
      end

      it 'updates obfuscated coordinates when longitude changes and generated flag is true' do
        site = create(:site, :with_lat_long)
        original_obfuscated_lng = site.obfuscated_longitude

        site.update!(longitude: site.longitude - site.longitude)

        expect(site.obfuscated_longitude).not_to eq(original_obfuscated_lng)
        expect(site.obfuscated_longitude).to be_within(Site::JITTER_RANGE).of(site.longitude)
      end

      it 'does not update obfuscated coordinates when custom_obfuscated_location is true' do
        site = create(:site, :with_lat_long)
        custom_obfuscated_lat = -45.0
        custom_obfuscated_lng = 145.0

        # Simulate user-provided obfuscated location
        site.update!(
          obfuscated_latitude: custom_obfuscated_lat,
          obfuscated_longitude: custom_obfuscated_lng,
          custom_obfuscated_location: true
        )

        # Now change the real coordinates
        site.update!(latitude: -30.0, longitude: 150.0)

        # Obfuscated should remain as user set them
        expect(site.obfuscated_latitude).to eq(custom_obfuscated_lat)
        expect(site.obfuscated_longitude).to eq(custom_obfuscated_lng)
        expect(site.custom_obfuscated_location).to be true
      end

      it 'does not update obfuscated coordinates when non-coordinate fields change' do
        site = create(:site, :with_lat_long)
        original_obfuscated_lat = site.obfuscated_latitude
        original_obfuscated_lng = site.obfuscated_longitude

        site.update!(name: 'new name')

        expect(site.obfuscated_latitude).to eq(original_obfuscated_lat)
        expect(site.obfuscated_longitude).to eq(original_obfuscated_lng)
      end
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
