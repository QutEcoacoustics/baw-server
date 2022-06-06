

describe TimeZoneHelper do
  it 'can map zones to offsets' do
    map = TimeZoneHelper.mapping_zone_to_offset

    expect(map).to include('Australia - Brisbane' => 'AEST (+10:00)')
  end

  it 'can find a timezone given an identifier' do
    timezone = TimeZoneHelper.find_timezone('Australia/Sydney')
    expect(timezone).to be_a_kind_of(TZInfo::Timezone)
    expect(timezone.friendly_identifier).to eq('Australia - Sydney')
  end

  it 'can find a timezone given a friendly identifier' do
    timezone = TimeZoneHelper.find_timezone('Australia - Sydney')
    expect(timezone).to be_a_kind_of(TZInfo::Timezone)
    expect(timezone.friendly_identifier).to eq('Australia - Sydney')
  end

  it 'can retrieve an identifier given an identifier' do
    identifier = TimeZoneHelper.to_identifier('Australia/Sydney')
    expect(identifier).to eq('Australia/Sydney')
  end

  it 'can retrieve an identifier given a friendly identifier' do
    identifier = TimeZoneHelper.to_identifier('Australia - Sydney')
    expect(identifier).to eq('Australia/Sydney')
  end

  it 'can test if a string is a valid identifier' do
    expect(TimeZoneHelper.identifier?('Australia/Sydney')).to be true
    expect(TimeZoneHelper.identifier?('Australia - Sydney')).to be false
    expect(TimeZoneHelper.identifier?(nil)).to be false
  end

  it 'can retrieve a friendly identifier given an identifier' do
    identifier = TimeZoneHelper.to_friendly('Australia/Sydney')
    expect(identifier).to eq('Australia - Sydney')
  end

  it 'can retrieve a friendly identifier given a friendly identifier' do
    identifier = TimeZoneHelper.to_friendly('Australia - Sydney')
    expect(identifier).to eq('Australia - Sydney')
  end

  it 'can get the ruby time zone class for a ruby tz name' do
    timezone = TimeZoneHelper.ruby_tz_class('Darwin')
    expect(timezone).to be_a(ActiveSupport::TimeZone)
  end

  it 'can get the TZInfo class for an identifier' do
    timezone = TimeZoneHelper.tzinfo_class('Australia/Sydney')
    expect(timezone).to be_a_kind_of(TZInfo::Timezone)
    expect(timezone.friendly_identifier).to eq('Australia - Sydney')
  end

  it 'can convert a ruby tz name to a TZInfo' do
    timezone = TimeZoneHelper.ruby_to_tzinfo('Darwin')
    expect(timezone).to be_a_kind_of(TZInfo::Timezone)
    expect(timezone.friendly_identifier).to eq('Australia - Darwin')
  end

  it 'can convert a tz identifier to a ruby tz name' do
    timezone = TimeZoneHelper.tz_identifier_to_ruby('Australia/Darwin')
    expect(timezone).to eq('Darwin')
  end

  it 'can convert a nil identifier to a nil ruby tz name' do
    timezone = TimeZoneHelper.tz_identifier_to_ruby(nil)
    expect(timezone).to eq(nil)
  end

  it 'can suggest timezone names' do
    suggestions = TimeZoneHelper.tzinfo_friendly_did_you_mean('Australia')
    expect(suggestions).to contain_exactly(
      'Australia - ACT',
      'Australia - Adelaide',
      'Australia - Brisbane',
      'Australia - Broken Hill',
      'Australia - Darwin',
      'Australia - Perth',
      'Australia - Sydney',
      'Australia - Melbourne',
      'Australia - Hobart',
      'Australia - Canberra',
      'Australia - Currie',
      'Australia - Eucla',
      'Australia - LHI',
      'Australia - Lord Howe',
      'Australia - Lindeman',
      'Australia - Tasmania',
      'Australia - Victoria',
      'Australia - West',
      'Australia - Yancowinna',
      'Australia - NSW',
      'Australia - North',
      'Australia - Queensland',
      'Australia - South'
    )
  end

  context 'can convert an offset in seconds into a readable timestamp' do
    [
      [-7200, '-02:00'], [0, '+00:00'], [15_300, '+04:15'], [36_000, '+10:00']
    ].each do |seconds, expected|
      example "#{seconds} ➡ #{expected}" do
        actual = TimeZoneHelper.offset_seconds_to_formatted(seconds)
        expect(actual).to eq(expected)
      end
    end
  end

  it 'can return a descriptive hash of a timezone' do
    darwin = TimeZoneHelper.tzinfo_class('Australia/Darwin')
    hash = TimeZoneHelper.info_hash('Australia/Darwin', 'Darwin')

    expect(hash).to eq({
      identifier_alt: 'Darwin',
      identifier: 'Australia/Darwin',
      friendly_identifier: 'Australia - Darwin',
      utc_offset: darwin.current_period.utc_offset,
      utc_total_offset: darwin.current_period.utc_total_offset
    })
  end
end
