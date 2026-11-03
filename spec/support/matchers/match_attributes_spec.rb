# frozen_string_literal: true

describe RSpec::Matchers, '#match_attributes' do # rubocop:disable RSpec/SpecFilePathFormat
  let(:timestamp) { Time.utc(2026, 1, 1) + Rational(123_456_789, 1_000_000_000) }
  let(:attributes) {
    { 'name' => 'unchanged', 'created_at' => timestamp, 'updated_at' => timestamp, 'deleted_at' => nil }
  }

  it 'allows sub-microsecond differences in every timestamp without modifying the snapshot' do
    actual = attributes.merge(
      'created_at' => timestamp + Rational(1, 2_000_000),
      'updated_at' => timestamp - Rational(1, 2_000_000)
    )

    expect(actual).to match_attributes(attributes)
    expect(attributes['created_at']).to eq(timestamp)
    expect(attributes['updated_at']).to eq(timestamp)
  end

  it 'rejects timestamp differences outside the tolerance in either direction' do
    [Rational(2, 1_000_000), Rational(-2, 1_000_000)].each do |difference|
      expect(attributes.merge('created_at' => timestamp + difference)).not_to match_attributes(attributes)
    end
  end

  it 'allows a difference of exactly one microsecond' do
    actual = attributes.merge('created_at' => timestamp + Rational(1, 1_000_000))

    expect(actual).to match_attributes(attributes)
  end

  it 'compares Time, DateTime and TimeWithZone values as instants in seconds' do
    [timestamp, timestamp.to_datetime, timestamp.in_time_zone('Brisbane')].each do |expected|
      [timestamp, timestamp.to_datetime, timestamp.in_time_zone('UTC')].each do |actual|
        expect({ 'created_at' => actual }).to match_attributes({ 'created_at' => expected })
        expect({ 'created_at' => actual + 1 }).not_to match_attributes({ 'created_at' => expected })
      end
    end
  end

  it 'allows an explicit tolerance in seconds' do
    expect(attributes.merge('created_at' => timestamp + 0.25))
      .to match_attributes(attributes, time_tolerance: 0.5)
  end

  it 'compares non-time values exactly' do
    actual = { count: 1.0000001 }

    expect(attributes.merge('name' => 'changed')).not_to match_attributes(attributes)
    expect(actual).not_to match_attributes({ count: 1 })
    expect({ date: Date.new(2026, 1, 2) }).not_to match_attributes({ date: Date.new(2026, 1, 1) })
  end

  it 'requires exactly the same keys' do
    expect(attributes.except('deleted_at')).not_to match_attributes(attributes)
    expect(attributes.merge('extra' => nil)).not_to match_attributes(attributes)
    expect(attributes.symbolize_keys).not_to match_attributes(attributes)
  end

  it 'does not treat nil or strings as timestamps' do
    expect(attributes.merge('created_at' => nil)).not_to match_attributes(attributes)
    expect(attributes.merge('created_at' => timestamp.iso8601)).not_to match_attributes(attributes)
    expect(attributes.merge('deleted_at' => timestamp)).not_to match_attributes(attributes)
  end

  it 'rejects a non-hash actual value' do
    actual = nil

    expect(actual).not_to match_attributes(attributes)
  end

  it 'includes an attribute diff in failure messages' do
    actual = { name: 'changed' }

    expect {
      expect(actual).to match_attributes({ name: 'original' })
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Diff:/)
  end
end
