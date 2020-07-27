require 'rails_helper'

describe TimeZoneAttribute do
  # extracted from prod so we can test possible cases
  CASES = [
    ['Australia - Darwin', 'Darwin', 'Australia/Darwin'],
    ['Asia - Makassar', '', 'Asia/Makassar'],
    ['Asia - Yangon', '', 'Asia/Yangon'],
    ['Australia - Melbourne', 'Melbourne', 'Australia/Melbourne'],
    ['Australia - Brisbane', 'Brisbane', 'Australia/Brisbane'],
    # this case represents a genuinely bad value that somehow ended up in the
    # database. No code that I could find would generate this value.
    ['UTC -2', '', nil],
    ['Asia - Thimphu', '', 'Asia/Thimphu'],
    ['US - Eastern', '', 'US/Eastern'],
    ['Australia - NSW', '', 'Australia/NSW'],
    ['America - Costa Rica', '', 'America/Costa_Rica'],
    ['Australia - Sydney', 'Sydney', 'Australia/Sydney'],
    ['Asia - Singapore', 'Singapore', 'Asia/Singapore'],
    ['Australia - Adelaide', 'Adelaide', 'Australia/Adelaide'],
    ['Asia - Dhaka', 'Dhaka', 'Asia/Dhaka'],
    ['Asia - Bangkok', 'Hanoi', 'Asia/Bangkok'],
    ['Australia - Hobart', 'Hobart', 'Australia/Hobart'],
    ['America - Lima', 'Quito', 'America/Lima'],
    ['America - Bogota', 'Bogota', 'America/Bogota'],
    ['Europe - Berlin', 'Bern', 'Europe/Berlin'],
    ['Pacific - Port Moresby', 'Port Moresby', 'Pacific/Port_Moresby'],
    ['Australia - Tasmania', '', 'Australia/Tasmania'],
    ['', nil, nil]
  ].freeze

  before(:all) do
    ActiveRecord::Base.connection.drop_table :temp_models, if_exists: true
    connection = ActiveRecord::Base.connection
    connection.create_table :temp_models do |t|
      t.column :tzinfo_tz, :string, null: true, limit: 255
      t.column :rails_tz, :string, null: true, limit: 255
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :temp_models
  end

  subject do
    class TempModel < ApplicationRecord
      include TimeZoneAttribute
    end
  end

  context 'fixing bad values in database' do
    CASES.each do |tzinfo_tz, rails_tz, expected|
      context [tzinfo_tz, rails_tz, expected] do
        it 'handles restoring bad values from the database' do
          # arrange
          rails_tz_db_string = rails_tz.nil? ? 'null' : "'#{rails_tz}'"
          insert_sql = "INSERT INTO temp_models (tzinfo_tz, rails_tz) VALUES ('#{tzinfo_tz}',#{rails_tz_db_string})"
          ActiveRecord::Base.connection.execute insert_sql

          # act
          loaded = subject.first

          # assert
          # value is normalized on read
          expect(loaded.tzinfo_tz).to eq(expected)
          # rails_tz is unmodified
          expect(loaded.rails_tz).to eq(rails_tz)

          # act
          loaded.save!
          results = ActiveRecord::Base.connection.exec_query('SELECT * FROM temp_models LIMIT 1')

          # assert
          expect(results.rows.first[1..]).to match([expected, rails_tz])
        end

        it 'normalizes values as they are assigned' do
          temp = subject.new
          temp.tzinfo_tz = tzinfo_tz

          # converted on assignment (unless the value was invalid!)
          if temp.valid?
            expect(temp.tzinfo_tz).to eq(expected)
          else
            expect(temp).to_not be_valid
          end

          # it sets rails tz at the same time
          expected_rails_tz = ActiveSupport::TimeZone::MAPPING.invert[expected]
          expect(temp.rails_tz).to eq(expected_rails_tz)
        end
      end
    end
  end

  context 'enures models have a timezone attribute that returns a hash' do
    example 'null timezone' do
      temp = subject.new

      actual = temp.timezone
      expect(actual).to be nil
    end

    example 'valid timezone' do
      darwin = TimeZoneHelper.tzinfo_class('Australia/Darwin')

      temp = subject.new
      temp.tzinfo_tz = 'Australia/Darwin'

      actual = temp.timezone

      expect(actual).to eq({
        identifier_alt: 'Darwin',
        identifier: 'Australia/Darwin',
        friendly_identifier: 'Australia - Darwin',
        utc_offset: darwin.current_period.utc_offset,
        utc_total_offset: darwin.current_period.utc_total_offset
      })
    end
  end

  it 'will add validation errors to the model' do
    temp = subject.new
    temp.tzinfo_tz = 'abc123'

    result = temp.save
    expect(result).to be false
    expect(temp).to_not be_valid
    expect(temp.errors[:tzinfo_tz]).to include("is not a recognized timezone ('abc123')")

    temp.tzinfo_tz = 'Australia/Brisbane'
    result = temp.save
    expect(result).to be true
    expect(temp).to be_valid
    expect(temp.errors).to be_empty
  end
end
